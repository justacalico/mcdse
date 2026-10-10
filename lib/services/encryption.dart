import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;

/// Ported from DungeonTools `IEncryptionProvider.cs`.
abstract class IEncryptionProvider {
  Future<Uint8List> decryptAsync(Uint8List encrypted);
  Future<Uint8List> encryptAsync(Uint8List decrypted);
}

/// AES-256-ECB with zero padding — the cipher Minecraft Dungeons uses for
/// character save files.
class AesEncryptionProvider implements IEncryptionProvider {
  AesEncryptionProvider(this._key);

  final Uint8List _key;

  @override
  Future<Uint8List> decryptAsync(Uint8List encrypted) async {
    final encrypter = _buildEncrypter();
    return Uint8List.fromList(
        encrypter.decryptBytes(enc.Encrypted(encrypted), iv: _iv));
  }

  @override
  Future<Uint8List> encryptAsync(Uint8List decrypted) async {
    // Zero-pad to a 16-byte boundary, like PaddingMode.Zeros.
    final remainder = decrypted.length % 16;
    final padded = remainder == 0
        ? decrypted
        : (Uint8List(decrypted.length + (16 - remainder))
          ..setRange(0, decrypted.length, decrypted));
    final encrypter = _buildEncrypter();
    return encrypter.encryptBytes(padded, iv: _iv).bytes;
  }

  enc.Encrypter _buildEncrypter() {
    return enc.Encrypter(enc.AES(enc.Key(_key),
        mode: enc.AESMode.ecb, padding: null));
  }

  static final _iv = enc.IV(Uint8List(16));
}

/// Encryption keys for character save files.
///
/// The key is publicly available in community tooling (e.g. the
/// minecraft_dungeons_sorter project). It can be overridden at runtime via
/// the `MCDSE_SAVE_KEY` environment variable (hex string, optional 0x).
abstract final class SaveKeys {
  static const String _embeddedKeyHex =
      '5ceb9d0aebb95ac0270b0af6753dfc0ee3e68bb69479020f2430e2ea002bd4c9';

  static Uint8List? _override;

  /// Loads an override key from the `MCDSE_SAVE_KEY` environment variable
  /// (hex string, optional `0x` prefix) or a compile-time define.
  static void initFromEnvironment() {
    const compileTime =
        String.fromEnvironment('MCDSE_SAVE_KEY', defaultValue: '');
    final text = compileTime.isNotEmpty
        ? compileTime
        : (Platform.environment['MCDSE_SAVE_KEY'] ?? '');
    if (text.isNotEmpty) {
      _override = parseHexKey(text);
    }
  }

  static void setOverride(Uint8List? key) => _override = key;

  static Uint8List? parseHexKey(String text) {
    var hex = text.trim();
    if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substring(2);
    if (hex.length != 64) return null;
    try {
      return Uint8List.fromList([
        for (var i = 0; i < 64; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
    } on FormatException {
      return null;
    }
  }

  static Uint8List get key => _override ?? parseHexKey(_embeddedKeyHex)!;
}

/// Ported from DungeonTools `RemoteEncryptionProvider.cs`.
///
/// The upstream application could be built without embedded keys, routing
/// encrypt/decrypt calls through a web service. Kept for parity.
class RemoteEncryptionProvider implements IEncryptionProvider {
  RemoteEncryptionProvider({http.Client? client, this.baseAddress = 'https://dungeons.tools/'})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseAddress;

  static const String encryptEndpoint = 'api/encryption/encrypt';
  static const String decryptEndpoint = 'api/encryption/decrypt';

  @override
  Future<Uint8List> decryptAsync(Uint8List encrypted) async {
    final data = await _callEndpoint(encrypted, null, decryptEndpoint);
    return base64Decode(_padBase64(data.decrypted!));
  }

  @override
  Future<Uint8List> encryptAsync(Uint8List decrypted) async {
    final data = await _callEndpoint(null, decrypted, encryptEndpoint);
    return base64Decode(_padBase64(data.encrypted!));
  }

  Future<_EncryptionData> _callEndpoint(
      Uint8List? encrypted, Uint8List? decrypted, String endpoint) async {
    final data = _EncryptionData(
      encrypted: encrypted == null ? null : base64Encode(encrypted),
      decrypted: decrypted == null ? null : base64Encode(decrypted),
    );
    final response = await _client.post(
      Uri.parse(baseAddress + endpoint),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data.toJson()),
    );
    return _EncryptionData.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  static String _padBase64(String base64) {
    return base64.padRight(
        base64.length + (4 - base64.length % 4) % 4, '=');
  }
}

class _EncryptionData {
  _EncryptionData({this.encrypted, this.decrypted});

  final String? encrypted;
  final String? decrypted;

  Map<String, dynamic> toJson() => {
        if (encrypted != null) 'Encrypted': encrypted,
        if (decrypted != null) 'Decrypted': decrypted,
      };

  factory _EncryptionData.fromJson(Map<String, dynamic> json) =>
      _EncryptionData(
        encrypted: json['Encrypted'] as String? ?? json['encrypted'] as String?,
        decrypted: json['Decrypted'] as String? ?? json['decrypted'] as String?,
      );
}

/// Entry point mirroring `EncryptionProviders.Current`.
abstract final class EncryptionProviders {
  static IEncryptionProvider _current = AesEncryptionProvider(SaveKeys.key);

  static IEncryptionProvider get current => _current;
  static set current(IEncryptionProvider provider) => _current = provider;

  static IEncryptionProvider local() => AesEncryptionProvider(SaveKeys.key);
  static IEncryptionProvider remote({http.Client? client}) =>
      RemoteEncryptionProvider(client: client);
}

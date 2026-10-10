import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

/// AES-256-ECB decryptor used for encrypted pak indexes and entries.
/// Ported from `AESDecryptor.cs` (Rijndael 128-bit block, zero padding).
abstract final class AesDecryptor {
  static Uint8List decryptAes(Uint8List data, Uint8List key) {
    final encrypter = enc.Encrypter(
        enc.AES(enc.Key(key), mode: enc.AESMode.ecb, padding: null));
    final padded = data.length % 16 == 0
        ? data
        : (Uint8List(data.length + 16 - data.length % 16)
          ..setRange(0, data.length, data));
    return Uint8List.fromList(
        encrypter.decryptBytes(enc.Encrypted(padded),
            iv: enc.IV(Uint8List(16))));
  }

  /// Try each candidate key against the start of an (encrypted) index, looking
  /// for a plausible FString length — ported from `AESDecryptor.FindKey` /
  /// `PakFileReader.TestAesKey`.
  static int findKey(Uint8List data, List<Uint8List> keys) {
    for (var i = 0; i < keys.length; i++) {
      if (testKey(data, keys[i])) return i;
    }
    return -1;
  }

  static bool testKey(Uint8List data, Uint8List key) {
    if (data.length < 16) return false;
    // Upstream decrypts the whole mount-point block (128 bytes).
    final amount = data.length >= 128 ? 128 : (data.length ~/ 16) * 16;
    final block = decryptAes(Uint8List.sublistView(data, 0, amount), key);
    final view = ByteData.sublistView(block);
    final stringLen = view.getInt32(0, Endian.little);
    if (stringLen > 128 || stringLen < -128) return false;
    if (stringLen == 0) return view.getUint16(4, Endian.little) == 0;
    if (stringLen < 0) {
      final pos = 4 + (-stringLen - 1) * 2;
      if (pos + 2 > block.length) return false;
      return view.getInt16(pos, Endian.little) == 0;
    }
    final pos = 4 + stringLen - 1;
    if (pos >= block.length) return false;
    return view.getInt8(pos) == 0;
  }
}

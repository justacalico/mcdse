import 'dart:convert';
import 'dart:typed_data';

import 'binary_reader.dart';
import 'objects.dart';

/// Ported from `Parsers/Objects/FPakInfo.cs` — the pak footer.
class FPakInfo {
  FPakInfo._();

  static const int pakFileMagic = 0x5A6F12E1;
  static const int compressionMethodNameLen = 32;

  EPakVersion version = EPakVersion.invalid;
  int subVersion = 0;
  int indexOffset = 0;
  int indexSize = 0;
  FShaHash? indexHash;
  bool bEncryptedIndex = false;
  FGuid? encryptionKeyGuid;
  List<String> compressionMethods = [];

  static const int serializedSize = 4 * 2 + 8 * 2 + 20 + 1 + 16;

  /// The pak footer is at the end of the file; the number of compression
  /// method names varies, so scan backwards until the magic matches.
  ///
  /// [baseOffset] is the absolute position of `fileBytes` within the pak —
  /// pass 0 when the bytes are the whole file.
  static FPakInfo readPakInfo(Uint8List fileBytes, {int baseOffset = 0}) {
    var offset = fileBytes.length - serializedSize;
    final terminator = offset - 300;
    var maxNumCompressionMethods = 0;
    while (offset > terminator) {
      final reader = PakBinaryReader(fileBytes, offset);
      final info = FPakInfo._read(reader, maxNumCompressionMethods);
      if (info.version != EPakVersion.invalid) {
        // indexOffset is stored as an absolute file position — do NOT add
        // baseOffset (the bytes scanned are the file's tail).
        return info;
      }
      offset -= compressionMethodNameLen;
      maxNumCompressionMethods++;
    }
    return FPakInfo._();
  }

  static FPakInfo _read(PakBinaryReader reader, int maxNumCompressionMethods) {
    final info = FPakInfo._();

    // Serialized when version >= EPakVersion.ENCRYPTION_KEY_GUID.
    info.encryptionKeyGuid = FGuid.read(reader);
    info.bEncryptedIndex = reader.readUint8() != 0;

    if (reader.readUInt32() != pakFileMagic) {
      return info; // invalid
    }

    info.version = EPakVersion.fromInt(reader.readInt32());
    int b;
    if (maxNumCompressionMethods == 5 &&
        info.version == EPakVersion.fnameBasedCompressionMethod) {
      // UE4.23
      b = (info.version.value << 4) | 1;
    } else {
      b = (info.version.value << 4) | 0;
    }
    info.subVersion = b & 15;
    info.indexOffset = reader.readInt64();
    info.indexSize = reader.readInt64();
    info.indexHash = FShaHash.read(reader);

    if (info.version.value < EPakVersion.fnameBasedCompressionMethod.value) {
      info.compressionMethods = const ['Zlib', 'Gzip', 'Oodle'];
    } else {
      final methodsBytes =
          reader.readBytes(compressionMethodNameLen * maxNumCompressionMethods);
      final methodList = <String>[];
      for (var i = 0; i < maxNumCompressionMethods; i++) {
        if (methodsBytes[i * compressionMethodNameLen] != 0) {
          var name = ascii.decode(Uint8List.sublistView(methodsBytes,
              i * compressionMethodNameLen, (i + 1) * compressionMethodNameLen));
          methodList.add(name.replaceAll('\x00', '').trimRight());
        }
      }
      info.compressionMethods = methodList;
    }
    return info;
  }
}

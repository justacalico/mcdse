import 'dart:typed_data';

/// Ported from DungeonTools `SaveFileHandler.cs`.
abstract final class SaveFileHandler {
  static const List<int> magic1 = [0x44, 0x30, 0x30, 0x31]; // "D001"
  static const List<int> magic2 = [0x00, 0x00, 0x00, 0x00];

  static bool isFileEncrypted(Uint8List data) => startsWithMagic(data);

  static bool startsWithMagic(Uint8List data) {
    if (data.length < magic1.length + magic2.length) return false;
    for (var i = 0; i < magic1.length; i++) {
      if (data[i] != magic1[i]) return false;
    }
    for (var i = 0; i < magic2.length; i++) {
      if (data[magic1.length + i] != magic2[i]) {
        throw const FormatException(
            'File started with magic but next 4 bytes were non-zero');
      }
    }
    return true;
  }

  /// Removes the trailing zero padding the cipher adds after the payload.
  static Uint8List removeTrailingZeroes(Uint8List data) {
    for (var i = 0; i < data.length; i++) {
      if (data[i] == 0) {
        return Uint8List.sublistView(data, 0, i);
      }
    }
    return data;
  }

  static Uint8List prependMagicToEncrypted(Uint8List encrypted) {
    final out = Uint8List(magic1.length + magic2.length + encrypted.length);
    out.setRange(0, 4, magic1);
    out.setRange(4, 8, magic2);
    out.setRange(8, out.length, encrypted);
    return out;
  }
}

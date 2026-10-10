import 'dart:convert';
import 'dart:typed_data';

/// Little-endian binary reader over a byte buffer — the Dart equivalent of
/// the C# `BinaryReader` usage in PakReader.
class PakBinaryReader {
  PakBinaryReader(this._data, [int offset = 0])
      : _position = offset;

  final Uint8List _data;
  int _position;

  late final ByteData _view =
      ByteData.sublistView(_data.buffer.asUint8List(_data.offsetInBytes, _data.lengthInBytes));

  int get position => _position;
  set position(int value) => _position = value;
  int get length => _data.length;

  void seek(int offset) => _position = offset;
  void skip(int bytes) => _position += bytes;

  int readUint8() => _data[_position++];
  int readInt8() => _view.getInt8(_position++);
  int readInt16() {
    final v = _view.getInt16(_position, Endian.little);
    _position += 2;
    return v;
  }

  int readUInt16() {
    final v = _view.getUint16(_position, Endian.little);
    _position += 2;
    return v;
  }

  int readInt32() {
    final v = _view.getInt32(_position, Endian.little);
    _position += 4;
    return v;
  }

  int readUInt32() {
    final v = _view.getUint32(_position, Endian.little);
    _position += 4;
    return v;
  }

  int readInt64() {
    final v = _view.getInt64(_position, Endian.little);
    _position += 8;
    return v;
  }

  int readUInt64() {
    final v = _view.getUint64(_position, Endian.little);
    _position += 8;
    return v;
  }

  double readFloat() {
    final v = _view.getFloat32(_position, Endian.little);
    _position += 4;
    return v;
  }

  double readDouble() {
    final v = _view.getFloat64(_position, Endian.little);
    _position += 8;
    return v;
  }

  Uint8List readBytes(int count) {
    final end = _position + count;
    final out = Uint8List.sublistView(_data, _position, end);
    _position = end;
    return out;
  }

  /// Reads an Unreal `FString`: int32 length (negative = UTF-16), data plus a
  /// null terminator.
  String? readFString() {
    var saveNum = readInt32();
    final loadUcs2 = saveNum < 0;
    if (loadUcs2) {
      if (saveNum == -2147483648) {
        throw const FormatException('Archive is corrupted');
      }
      saveNum = -saveNum;
    }
    if (saveNum == 0) return null;

    if (loadUcs2) {
      final units = List<int>.generate(saveNum, (_) => readUInt16());
      // Drop the null terminator.
      return String.fromCharCodes(units.sublist(0, units.length - 1));
    }
    final bytes = readBytes(saveNum);
    return utf8.decode(bytes.sublist(0, saveNum - 1), allowMalformed: true);
  }

  List<T> readTArray<T>(T Function() getter) {
    final serializeNum = readInt32();
    return List<T>.generate(serializeNum, (_) => getter());
  }
}

int alignInt(int val, int alignment) => (val + alignment - 1) & ~(alignment - 1);

Uint8List hexToBytes(String hex) {
  var h = hex.trim();
  if (h.startsWith('0x') || h.startsWith('0X')) h = h.substring(2);
  final out = Uint8List(h.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

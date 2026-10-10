import 'dart:io';
import 'dart:typed_data';

/// A seekable byte source — either a file on disk (read on demand, low memory)
/// or an in-memory buffer (tests).
abstract class PakSource {
  int get length;
  Uint8List read(int offset, int count);
  void close();
}

class FilePakSource implements PakSource {
  FilePakSource(String path) : _file = File(path).openSync() {
    _length = _file.lengthSync();
  }

  final RandomAccessFile _file;
  late final int _length;

  @override
  int get length => _length;

  @override
  Uint8List read(int offset, int count) {
    _file.setPositionSync(offset);
    return Uint8List.fromList(_file.readSync(count));
  }

  @override
  void close() {
    try {
      _file.closeSync();
    } catch (_) {}
  }
}

class MemoryPakSource implements PakSource {
  MemoryPakSource(this.bytes);
  final Uint8List bytes;

  @override
  int get length => bytes.length;

  @override
  Uint8List read(int offset, int count) =>
      Uint8List.sublistView(bytes, offset, offset + count);

  @override
  void close() {}
}

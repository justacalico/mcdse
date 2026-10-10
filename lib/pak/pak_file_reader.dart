import 'dart:typed_data';

import 'aes_decryptor.dart';
import 'binary_reader.dart';
import 'fpak_info.dart';
import 'objects.dart';
import 'pak_filter.dart';
import 'pak_source.dart';
import 'paks.dart';

/// Ported from `Pak/PakFileReader.cs`.
///
/// Data is read lazily through [PakSource] so multi-GB paks don't need to be
/// resident in memory.
class PakFileReader {
  PakFileReader(String path, {bool caseSensitive = true})
      : this._(FilePakSource(path), path.split(RegExp(r'[/\\]')).last,
            caseSensitive);

  PakFileReader.fromBytes(Uint8List bytes, String name,
      {bool caseSensitive = true})
      : this._(MemoryPakSource(bytes), name, caseSensitive);

  PakFileReader._(this.source, this.fileName, this.caseSensitive) {
    info = FPakInfo.readPakInfo(
        source.read(source.length - _footerScanSize > 0
            ? source.length - _footerScanSize
            : 0,
            _footerScanSize > source.length ? source.length : _footerScanSize),
        baseOffset: source.length - _footerScanSize > 0
            ? source.length - _footerScanSize
            : 0);
    mountArray =
        source.read(info.indexOffset, 128.clamp(0, source.length - info.indexOffset));
  }

  static const int _footerScanSize = 600; // serializedSize(45)+300 scan margin

  final PakSource source;
  final String fileName;
  final bool caseSensitive;

  late FPakInfo info;
  late Uint8List mountArray;

  Uint8List? aesKey;
  String mountPoint = '';
  bool initialized = false;
  Map<String, FPakEntry> entries = {};

  bool testAesKey(Uint8List key) {
    if (!info.bEncryptedIndex) return true;
    return AesDecryptor.testKey(mountArray, key);
  }

  /// Returns null on success, or the error.
  Object? tryReadIndex(Uint8List? key, [PakFilter? filter]) {
    try {
      _readIndexInternal(key, filter);
      return null;
    } catch (e) {
      return e;
    }
  }

  Uint8List _readAt(int offset, int count) => source.read(offset, count);

  void _readIndexInternal(Uint8List? key, PakFilter? filter) {
    if (initialized) {
      throw StateError('Index is already initialized');
    }
    if (info.bEncryptedIndex && key == null) {
      throw ArgumentError('Index is encrypted but no key was provided');
    }

    PakBinaryReader indexReader;
    if (info.bEncryptedIndex) {
      final decrypted = AesDecryptor.decryptAes(
          source.read(info.indexOffset, info.indexSize), key!);
      indexReader = PakBinaryReader(decrypted);
      final stringLen = indexReader.readInt32();
      if (stringLen > 512 || stringLen < -512) {
        throw ArgumentError('The provided key is invalid');
      }
      if (stringLen < 0) {
        indexReader.position += (-stringLen - 1) * 2;
        if (indexReader.readUInt16() != 0) {
          throw ArgumentError('The provided key is invalid');
        }
      } else {
        indexReader.position += stringLen - 1;
        if (indexReader.readUint8() != 0) {
          throw ArgumentError('The provided key is invalid');
        }
      }
      indexReader.position = 0;
    } else {
      indexReader =
          PakBinaryReader(source.read(info.indexOffset, info.indexSize));
    }

    Map<String, FPakEntry> tempFiles;
    if (info.version.value >= EPakVersion.pathHashIndex.value) {
      tempFiles = _readIndexUpdated(indexReader, key, filter);
    } else {
      mountPoint = indexReader.readFString() ?? '';
      if (mountPoint.startsWith('../../..')) {
        mountPoint = mountPoint.substring(8);
      } else {
        mountPoint = '/';
      }
      if (!caseSensitive) {
        mountPoint = mountPoint.toLowerCase();
      }

      final numEntries = indexReader.readInt32();
      tempFiles = {};
      for (var i = 0; i < numEntries; i++) {
        final entry = FPakEntry.read(
            indexReader, info.version, info.subVersion, caseSensitive, fileName);
        if (filter == null ||
            filter.checkFilter(mountPoint + entry.name, caseSensitive)) {
          tempFiles[entry.name] = entry;
        }
      }
    }

    entries = Paks.merge(tempFiles, mountPoint);
    aesKey = key;
    initialized = true;
  }

  Map<String, FPakEntry> _readIndexUpdated(
      PakBinaryReader reader, Uint8List? aesKey, PakFilter? filter) {
    mountPoint = reader.readFString() ?? '';
    if (mountPoint.startsWith('../../..')) {
      mountPoint = mountPoint.substring(8);
    } else {
      mountPoint = '/';
    }
    if (!caseSensitive) mountPoint = mountPoint.toLowerCase();
    reader.readInt32(); // numEntries
    reader.readUInt64(); // PathHashSeed

    if (reader.readInt32() == 0) {
      throw const FormatException('No path hash index');
    }
    reader.skip(8 + 8 + 20); // PathHashIndexOffset + Size + Hash

    if (reader.readInt32() == 0) {
      throw const FormatException('No directory index');
    }

    final fullDirectoryIndexOffset = reader.readInt64();
    final fullDirectoryIndexSize = reader.readInt64();
    reader.skip(20); // FullDirectoryIndexHash

    final encodedPakEntries = reader.readTArray(() => reader.readUint8());

    final filesNum = reader.readInt32();
    if (filesNum < 0) {
      throw const FormatException('Corrupt pak PrimaryIndex detected!');
    }

    var pathHashIndexData = source.read(
        fullDirectoryIndexOffset, fullDirectoryIndexSize);
    if (info.bEncryptedIndex) {
      pathHashIndexData = AesDecryptor.decryptAes(pathHashIndexData, aesKey!);
    }

    final pathHashIndexReader = PakBinaryReader(pathHashIndexData);
    final pathHashIndex = pathHashIndexReader
        .readTArray(() => FPakDirectoryEntry.read(pathHashIndexReader));

    final dict = <String, FPakEntry>{};
    for (final directoryEntry in pathHashIndex) {
      for (final hashIndexEntry in directoryEntry.entries) {
        var path = directoryEntry.directory + hashIndexEntry.filename;
        if (path.startsWith('/')) path = path.substring(1);
        if (!caseSensitive) path = path.toLowerCase();
        if (filter == null ||
            filter.checkFilter(
                mountPoint + hashIndexEntry.filename, caseSensitive)) {
          dict[path] =
              _getEntry(path, hashIndexEntry.location, encodedPakEntries);
        }
      }
    }
    return dict;
  }

  FPakEntry _getEntry(
      String name, int pakLocation, List<int> encodedPakEntries) {
    if (pakLocation < 0) {
      throw const FormatException("list indexes aren't supported");
    }
    final bytes = Uint8List.fromList(encodedPakEntries);
    final view = ByteData.sublistView(bytes);
    var loc = pakLocation;

    final value = view.getUint32(loc, Endian.little);
    loc += 4;

    final compressionMethodIndex = (value >> 23) & 0x3f;

    final isOffset32BitSafe = (value & (1 << 31)) != 0;
    int offset;
    if (isOffset32BitSafe) {
      offset = view.getUint32(loc, Endian.little);
      loc += 4;
    } else {
      offset = view.getInt64(loc, Endian.little);
      loc += 8;
    }

    final isUncompressedSize32BitSafe = (value & (1 << 30)) != 0;
    int uncompressedSize;
    if (isUncompressedSize32BitSafe) {
      uncompressedSize = view.getUint32(loc, Endian.little);
      loc += 4;
    } else {
      uncompressedSize = view.getInt64(loc, Endian.little);
      loc += 8;
    }

    int size;
    if (compressionMethodIndex != 0) {
      final isSize32BitSafe = (value & (1 << 29)) != 0;
      if (isSize32BitSafe) {
        size = view.getUint32(loc, Endian.little);
        loc += 4;
      } else {
        size = view.getInt64(loc, Endian.little);
        loc += 8;
      }
    } else {
      size = uncompressedSize;
    }

    final encrypted = (value & (1 << 22)) != 0;
    const deleted = false;

    final compressionBlocksCount = (value >> 6) & 0xffff;
    final compressionBlocks = List<FPakCompressedBlock>.filled(
        compressionBlocksCount, FPakCompressedBlock(0, 0));

    var compressionBlockSize = 0;
    if (compressionBlocksCount > 0) {
      compressionBlockSize =
          uncompressedSize < 65536 ? uncompressedSize : ((value & 0x3f) << 11);
    }

    const baseOffset = 0;
    if (compressionBlocks.length == 1 && !encrypted) {
      final start = baseOffset +
          FPakEntry.getSize(EPakVersion.invalid,
              compressionMethodIndex, compressionBlocksCount);
      compressionBlocks[0] = FPakCompressedBlock(start, start + size);
    } else if (compressionBlocks.isNotEmpty) {
      final compressedBlockAlignment = encrypted ? 16 : 1;
      var compressedBlockOffset = baseOffset +
          FPakEntry.getSize(EPakVersion.invalid,
              compressionMethodIndex, compressionBlocksCount);
      for (var i = 0; i < compressionBlocks.length; i++) {
        final block = FPakCompressedBlock(compressedBlockOffset,
            compressedBlockOffset + view.getUint32(loc, Endian.little));
        compressionBlocks[i] = block;
        compressedBlockOffset += alignInt(block.size, compressedBlockAlignment);
        loc += 4;
      }
    }

    return FPakEntry.encoded(
        fileName,
        name,
        offset,
        size,
        uncompressedSize,
        compressionBlocksCount > 0 ? compressionBlocks : null,
        compressionBlockSize,
        compressionMethodIndex,
        (encrypted ? 0x01 : 0x00) | (deleted == true ? 0x02 : 0x00));
  }

  /// Returns (uasset, uexp, ubulk) data for [path].
  (Uint8List?, Uint8List?, Uint8List?) tryGetFile(String path) {
    final key = caseSensitive ? path : path.toLowerCase();
    final entry = entries[key];
    if (entry == null) return (null, null, null);
    return (
      entry.getData(_readAt, aesKey, info.compressionMethods),
      entry.hasUexp()
          ? entry.uexp!.getData(_readAt, aesKey, info.compressionMethods)
          : null,
      entry.hasUbulk()
          ? entry.ubulk!.getData(_readAt, aesKey, info.compressionMethods)
          : null,
    );
  }
}

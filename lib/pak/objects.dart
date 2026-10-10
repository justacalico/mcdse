import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'aes_decryptor.dart';
import 'binary_reader.dart';

/// UE4 pak/version-related objects ported from `Parsers/Objects/*`.

enum EPakVersion {
  initial(1),
  noTimestamps(2),
  compressionEncryption(3),
  indexEncryption(4),
  relativeChunkOffsets(5),
  deleteRecords(6),
  encryptionKeyGuid(7),
  fnameBasedCompressionMethod(8),
  frozenIndex(9),
  pathHashIndex(10),
  invalid(99);

  const EPakVersion(this.value);
  final int value;

  static const int latest = 10;

  static EPakVersion fromInt(int v) =>
      EPakVersion.values.firstWhere((e) => e.value == v,
          orElse: () => EPakVersion.invalid);
}

class FGuid {
  FGuid(this.a, this.b, this.c, this.d);

  FGuid.read(PakBinaryReader reader)
      : a = reader.readUInt32(),
        b = reader.readUInt32(),
        c = reader.readUInt32(),
        d = reader.readUInt32();

  static final FGuid zero = FGuid(0, 0, 0, 0);

  final int a;
  final int b;
  final int c;
  final int d;

  @override
  bool operator ==(Object other) =>
      other is FGuid && a == other.a && b == other.b && c == other.c && d == other.d;

  @override
  int get hashCode => Object.hash(a, b, c, d);
}

class FShaHash {
  FShaHash.read(PakBinaryReader reader) : hash = reader.readBytes(20);

  final Uint8List hash;
}

class FPakCompressedBlock {
  FPakCompressedBlock(this.compressedStart, this.compressedEnd)
      : size = compressedEnd - compressedStart;

  FPakCompressedBlock.read(PakBinaryReader reader)
      : compressedStart = reader.readInt64(),
        compressedEnd = reader.readInt64(),
        size = 0 {
    size = compressedEnd - compressedStart;
  }

  final int compressedStart;
  final int compressedEnd;
  int size;
}

abstract final class ECompressionFlags {
  static const int none = 0x00;
  static const int zlib = 0x01;
  static const int gzip = 0x02;
  static const int custom = 0x04;
}

class FPakEntry {
  FPakEntry._();

  factory FPakEntry.read(PakBinaryReader reader, EPakVersion version,
      int subVersion, bool caseSensitive, String pakName) {
    final entry = FPakEntry._()
      ..pakFileName = pakName
      ..compressionBlocks = null
      ..compressionBlockSize = 0
      ..flags = 0;

    var name = reader.readFString() ?? '';
    if (!caseSensitive) name = name.toLowerCase();
    entry.name = name.startsWith('/') ? name.substring(1) : name;

    final startOffset = reader.position;

    entry.offset = reader.readInt64();
    entry.size = reader.readInt64();
    entry.uncompressedSize = reader.readInt64();
    if (version.value < EPakVersion.fnameBasedCompressionMethod.value) {
      final legacyCompressionMethod = reader.readInt32();
      if (legacyCompressionMethod == ECompressionFlags.none) {
        entry.compressionMethodIndex = 0;
      } else if (legacyCompressionMethod & ECompressionFlags.zlib != 0) {
        entry.compressionMethodIndex = 1;
      } else if (legacyCompressionMethod & ECompressionFlags.gzip != 0) {
        entry.compressionMethodIndex = 2;
      } else if (legacyCompressionMethod & ECompressionFlags.custom != 0) {
        entry.compressionMethodIndex = 3;
      } else {
        throw const FormatException(
            'Found an unknown compression type in pak file');
      }
    } else {
      if (version == EPakVersion.fnameBasedCompressionMethod &&
          subVersion == 0) {
        entry.compressionMethodIndex = reader.readUint8();
      } else {
        entry.compressionMethodIndex = reader.readUInt32();
      }
    }
    if (version.value <= EPakVersion.initial.value) reader.readInt64();
    reader.skip(20); // hash
    if (version.value >= EPakVersion.compressionEncryption.value) {
      if (entry.compressionMethodIndex != 0) {
        entry.compressionBlocks =
            reader.readTArray(() => FPakCompressedBlock.read(reader));
      }
      entry.flags = reader.readUint8();
      entry.compressionBlockSize = reader.readUInt32();
    }

    entry.structSize = reader.position - startOffset;
    return entry;
  }

  /// "New" format entry used by PATH_HASH_INDEX paks.
  factory FPakEntry.readNewFormat(
      PakBinaryReader reader, bool caseSensitive, String pakName) {
    final entry = FPakEntry._()
      ..pakFileName = pakName
      ..compressionBlocks = null
      ..compressionBlockSize = 0
      ..flags = 0;

    var name = reader.readFString() ?? '';
    if (!caseSensitive) name = name.toLowerCase();
    entry.name = name;

    final startOffset = reader.position;
    entry.offset = reader.readInt64();
    entry.size = reader.readInt64();
    entry.uncompressedSize = reader.readInt64();
    entry.compressionMethodIndex = reader.readUInt32();
    reader.skip(20); // hash
    if (entry.compressionMethodIndex != 0) {
      entry.compressionBlocks =
          reader.readTArray(() => FPakCompressedBlock.read(reader));
    }
    entry.flags = reader.readUint8();
    entry.compressionBlockSize = reader.readUInt32();
    entry.structSize = reader.position - startOffset;
    return entry;
  }

  /// Entry assembled from the encoded bitfield format (path-hash index paks).
  FPakEntry.encoded(
    this.pakFileName,
    this.name,
    this.offset,
    this.size,
    this.uncompressedSize,
    this.compressionBlocks,
    this.compressionBlockSize,
    this.compressionMethodIndex,
    this.flags,
  ) {
    structSize = getSize(EPakVersion.invalid, compressionMethodIndex,
        compressionBlocks?.length ?? 0);
  }

  late final String pakFileName;
  late String name;
  late int offset;
  late int size;
  late int uncompressedSize;
  List<FPakCompressedBlock>? compressionBlocks;
  late int compressionBlockSize;
  late int compressionMethodIndex;
  late int flags;
  late int structSize;

  static const int flagEncrypted = 0x01;
  static const int flagDeleted = 0x02;

  bool get encrypted => (flags & flagEncrypted) != 0;
  bool get deleted => (flags & flagDeleted) != 0;

  FPakEntry? uexp;
  FPakEntry? ubulk;

  bool hasUexp() => uexp != null;
  bool hasUbulk() => ubulk != null;

  bool isUE4Package() => extension == '.uasset';
  bool isLocres() => extension == '.locres';
  bool isUE4Map() => extension == '.umap';
  bool isUE4Font() => extension == '.ufont';

  String get extension {
    final idx = name.lastIndexOf('.');
    return idx < 0 ? '' : name.substring(idx);
  }

  String get pathWithoutExtension {
    final idx = name.lastIndexOf('.');
    return idx < 0 ? name : name.substring(0, idx);
  }

  /// Reads the file data via [readAt] — `readAt(offset, count)` returns the
  /// pak's bytes at an absolute offset.
  Uint8List? getData(Uint8List Function(int offset, int count) readAt,
      Uint8List? key, List<String> compressionMethods) {
    if (compressionMethodIndex == 0) {
      final start = offset + structSize;
      if (encrypted) {
        final readLen = size % 16 == 0 ? size : (size ~/ 16 + 1) * 16;
        final data = readAt(start, readLen);
        final dec = aesDecrypt(data, key!);
        return Uint8List.sublistView(dec, 0, uncompressedSize);
      }
      return readAt(start, uncompressedSize);
    }
    return _decompress(readAt, key, compressionMethods);
  }

  Uint8List _decompress(Uint8List Function(int, int) readAt, Uint8List? key,
      List<String> compressionMethods) {
    if (compressionMethods.isEmpty) {
      throw ArgumentError('CompressionMethods are null or empty');
    }
    final compressionMethod = compressionMethods[compressionMethodIndex - 1];
    final outData = Uint8List(uncompressedSize);
    var bytesRead = 0;
    for (final block in compressionBlocks!) {
      final start = offset + block.compressedStart;
      final uncompressedSize = compressionBlockSize < outData.length - bytesRead
          ? compressionBlockSize
          : outData.length - bytesRead;

      Uint8List blockBuffer;
      if (encrypted) {
        final readLen = alignInt(block.size, 16);
        blockBuffer = aesDecrypt(readAt(start, readLen), key!);
      } else {
        blockBuffer = readAt(start, block.size);
      }

      switch (compressionMethod) {
        case 'Zlib':
          final decoded = zlibDecode(blockBuffer);
          final n = decoded.length < uncompressedSize
              ? decoded.length
              : uncompressedSize;
          outData.setRange(bytesRead, bytesRead + n, decoded);
          bytesRead += n;
        case 'Gzip':
          final decoded = gzipDecode(blockBuffer);
          final n = decoded.length < uncompressedSize
              ? decoded.length
              : uncompressedSize;
          outData.setRange(bytesRead, bytesRead + n, decoded);
          bytesRead += n;
        default:
          throw UnimplementedError(
              'Decompression not yet implemented ($compressionMethod)');
      }
    }
    return outData;
  }

  static int getSize(EPakVersion version,
      [int compressionMethodIndex = 0, int compressionBlocksCount = 0]) {
    var serializedSize = 8 + 8 + 8 + 20;
    if (version == EPakVersion.invalid ||
        version.value >= EPakVersion.fnameBasedCompressionMethod.value) {
      serializedSize += 4;
    } else {
      serializedSize += 4; // old compression-method int32
    }
    if (version == EPakVersion.invalid ||
        version.value >= EPakVersion.compressionEncryption.value) {
      serializedSize += 1 + 4;
      if (compressionMethodIndex != 0) {
        serializedSize += 16 * compressionBlocksCount + 4;
      }
    }
    if (version != EPakVersion.invalid &&
        version.value < EPakVersion.noTimestamps.value) {
      serializedSize += 8;
    }
    return serializedSize;
  }

  @override
  String toString() => name;
}

Uint8List aesDecrypt(Uint8List data, Uint8List key) =>
    AesDecryptor.decryptAes(data, key);
Uint8List zlibDecode(Uint8List data) =>
    Uint8List.fromList(ZLibDecoder().decodeBytes(data));
Uint8List gzipDecode(Uint8List data) =>
    Uint8List.fromList(GZipDecoder().decodeBytes(data));

class FPakDirectoryEntry {
  FPakDirectoryEntry.read(PakBinaryReader reader)
      : directory = reader.readFString() ?? '',
        entries = reader.readTArray(() => FPathHashIndexEntry.read(reader));

  final String directory;
  final List<FPathHashIndexEntry> entries;
}

class FPathHashIndexEntry {
  FPathHashIndexEntry.read(PakBinaryReader reader)
      : filename = reader.readFString() ?? '',
        location = reader.readInt32();

  final String filename;
  final int location;
}

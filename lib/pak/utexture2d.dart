import 'dart:typed_data';

import 'binary_reader.dart';
import 'package_reader.dart';
import 'texture_decoder.dart';
import 'uobject.dart';

/// Ported from `Parsers/Class/UTexture2D.cs` + texture objects.
class UTexture2D extends UObject {
  UTexture2D.read(PackageReader reader, PakBinaryReader? ubulk, int bulkOffset)
      : super(reader) {
    // FStripDataFlags ×2 — "still no idea why there are two".
    reader.readUint8();
    reader.readUint8();
    reader.readUint8();
    reader.readUint8();

    if (reader.readInt32() != 0) {
      // bIsCooked
      final data = <FTexturePlatformData>[];
      var pixelFormatName = reader.readFName();
      // MCD's pak version is FNAME_BASED_COMPRESSION_METHOD (8), which is
      // >= INDEX_ENCRYPTION so the post-loop read applies.
      while (!pixelFormatName.isNone && pixelFormatName.string.isNotEmpty) {
        reader.readInt64(); // SkipOffset
        data.add(FTexturePlatformData.read(reader, ubulk, bulkOffset));
        pixelFormatName = reader.readFName();
      }
      platformDatas = data;
    }
  }

  List<FTexturePlatformData> platformDatas = const [];

  /// Decoded RGBA8 pixels of the first mip of the first platform data.
  Uint8List? decodeRgba() {
    if (platformDatas.isEmpty || platformDatas[0].mips.isEmpty) return null;
    final platformData = platformDatas[0];
    final mip = platformData.mips[0];
    final bulkData = mip.bulkData;
    if (bulkData == null) return null;
    return TextureDecoder.decodeImage(
        bulkData, mip.sizeX, mip.sizeY, mip.sizeZ, platformData.pixelFormat);
  }
}

class FTexturePlatformData {
  FTexturePlatformData.read(
      PackageReader reader, PakBinaryReader? ubulk, int bulkOffset) {
    sizeX = reader.readInt32();
    sizeY = reader.readInt32();
    numSlices = reader.readInt32();
    pixelFormat = reader.readFString() ?? '';
    reader.readInt32(); // FirstMipToSerialize (ignored, same as upstream)
    mips = reader.readTArray(() => FTexture2DMipMap.read(reader, ubulk, bulkOffset));
  }

  late int sizeX;
  late int sizeY;
  late int numSlices;
  late String pixelFormat;
  late List<FTexture2DMipMap> mips;
}

class FTexture2DMipMap {
  FTexture2DMipMap.read(
      PackageReader reader, PakBinaryReader? ubulk, int bulkOffset) {
    reader.readInt32(); // bCooked
    bulkData = FByteBulkData.read(reader, ubulk, bulkOffset);
    sizeX = reader.readInt32();
    sizeY = reader.readInt32();
    sizeZ = reader.readInt32();
  }

  late Uint8List? bulkData;
  late int sizeX;
  late int sizeY;
  late int sizeZ;
}

abstract final class EBulkDataFlags {
  static const int forceInlinePayload = 1 << 6;
  static const int payloadInSeparateFile = 1 << 8;
}

class FByteBulkData {
  static Uint8List? read(
      PackageReader reader, PakBinaryReader? ubulk, int ubulkOffset) {
    final bulkDataFlags = reader.readUInt32();
    final elementCount = reader.readInt32();
    reader.readInt32(); // BulkDataSizeOnDisk
    final bulkDataOffsetInFile = reader.readInt64();

    if (bulkDataFlags & EBulkDataFlags.forceInlinePayload != 0 &&
        elementCount > 0) {
      return reader.readBytes(elementCount);
    }

    if (bulkDataFlags & EBulkDataFlags.payloadInSeparateFile != 0 &&
        ubulk != null) {
      ubulk.position = bulkDataOffsetInFile + ubulkOffset;
      return ubulk.readBytes(elementCount);
    }
    return null;
  }
}

import 'binary_reader.dart';
import 'objects.dart';

/// Ported from `FPackageFileSummary.cs` — the .uasset header.
class FPackageFileSummary {
  FPackageFileSummary.read(PakBinaryReader reader) {
    const packageFileTag = 0x9E2A83C1;
    const packageFileTagSwapped = 0xC1832A9E;

    var tag = reader.readUInt32();
    if (tag != packageFileTag && tag != packageFileTagSwapped) {
      throw const FormatException('Not a UE package');
    }
    if (tag == packageFileTagSwapped) {
      throw UnimplementedError(
          'Byte swapping for packages not implemented');
    }

    final legacyFileVersion = reader.readInt32();
    if (legacyFileVersion < 0) {
      if (legacyFileVersion < -7) {
        throw const FormatException("Can't load legacy UE3 file");
      }
      if (legacyFileVersion != -4) {
        reader.skip(4); // LegacyUE3Version
      }
      fileVersionUE4 = reader.readInt32();
      fileVersionLicenseeUE4 = reader.readInt32();

      if (legacyFileVersion <= -2) {
        // FCustomVersionContainer
        reader.readTArray(() {
          FGuid.read(reader); // key
          reader.readInt32(); // version
          return 0;
        });
      }

      if (fileVersionUE4 != 0 && fileVersionLicenseeUE4 != 0) {
        bUnversioned = true;
      }
    } else {
      throw const FormatException("Can't load legacy UE3 file");
    }

    totalHeaderSize = reader.readInt32();
    folderName = reader.readFString() ?? '';
    packageFlags = reader.readUInt32();
    nameCount = reader.readInt32();
    nameOffset = reader.readInt32();

    gatherableTextDataCount = reader.readInt32();
    gatherableTextDataOffset = reader.readInt32();

    exportCount = reader.readInt32();
    exportOffset = reader.readInt32();
    importCount = reader.readInt32();
    importOffset = reader.readInt32();
    dependsOffset = reader.readInt32();

    softPackageReferencesCount = reader.readInt32();
    softPackageReferencesOffset = reader.readInt32();

    searchableNamesOffset = reader.readInt32();
    thumbnailTableOffset = reader.readInt32();
    guid = FGuid.read(reader);

    final generationCount = reader.readInt32();
    for (var i = 0; i < generationCount; i++) {
      reader.skip(8); // FGenerationInfo: ExportCount + NameCount
    }

    // FEngineVersion ×2
    for (var i = 0; i < 2; i++) {
      reader.skip(2 + 2 + 2 + 4);
      reader.readFString(); // branch
    }

    final compressionFlags = reader.readUInt32();
    if (compressionFlags != 0) {
      throw FormatException('Incompatible compression flags ($compressionFlags)');
    }

    // "CompressedChunks" must be empty.
    if (reader.readTArray(() => reader.readInt32() + reader.readInt32() + reader.readInt32() + reader.readInt32()).isNotEmpty) {
      throw const FormatException('Package level compression is enabled');
    }

    packageSource = reader.readUInt32();
    reader.readTArray(() => reader.readFString()); // AdditionalPackagesToCook

    if (legacyFileVersion > -7) {
      if (reader.readInt32() != 0) {
        throw const FormatException("Can't load legacy UE3 file");
      }
    }

    assetRegistryDataOffset = reader.readInt32();
    bulkDataStartOffset = reader.readInt64();
    worldTileInfoDataOffset = reader.readInt32();
    reader.readTArray(() => reader.readInt32()); // ChunkIDs
    preloadDependencyCount = reader.readInt32();
    preloadDependencyOffset = reader.readInt32();
  }

  int fileVersionUE4 = 0;
  int fileVersionLicenseeUE4 = 0;
  int totalHeaderSize = 0;
  int packageFlags = 0;
  String folderName = '';
  int nameCount = 0;
  int nameOffset = 0;
  int gatherableTextDataCount = 0;
  int gatherableTextDataOffset = 0;
  int exportCount = 0;
  int exportOffset = 0;
  int importCount = 0;
  int importOffset = 0;
  int dependsOffset = 0;
  int softPackageReferencesCount = 0;
  int softPackageReferencesOffset = 0;
  int searchableNamesOffset = 0;
  int thumbnailTableOffset = 0;
  FGuid? guid;
  int packageSource = 0;
  bool bUnversioned = false;
  int assetRegistryDataOffset = 0;
  int bulkDataStartOffset = 0;
  int worldTileInfoDataOffset = 0;
  int preloadDependencyCount = 0;
  int preloadDependencyOffset = 0;
}

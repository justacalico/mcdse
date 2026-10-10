import 'dart:typed_data';

import 'binary_reader.dart';
import 'package_objects.dart';
import 'package_summary.dart';
import 'utexture2d.dart';
import 'uobject.dart';

/// Ported from `Parsers/PackageReader.cs` — reads a cooked .uasset/.uexp
/// pair (plus optional .ubulk) and produces typed exports.
class PackageReader {
  PackageReader(Uint8List uasset, Uint8List uexp, Uint8List? ubulk)
      : _uassetReader = PakBinaryReader(uasset) {
    loader = _uassetReader;
    packageFileSummary = FPackageFileSummary.read(loader);
    nameMap = _serializeNameMap();
    importMap = _serializeImportMap();
    exportMap = _serializeExportMap();

    dataExports = List<UObject?>.filled(exportMap.length, null);
    dataExportTypes = List<FName>.filled(exportMap.length, const FName.empty());

    loader = PakBinaryReader(uexp);
    final bulk = ubulk == null ? null : PakBinaryReader(ubulk);
    final maxSerial =
        exportMap.fold<int>(0, (sum, e) => sum + e.serialSize) +
            packageFileSummary.totalHeaderSize;
    for (var i = 0; i < exportMap.length; i++) {
      final export = exportMap[i];
      FName exportType;
      if (export.classIndex.isNull) {
        exportType = dataExportTypes[i] = readFName();
      } else if (export.classIndex.isExport) {
        exportType = dataExportTypes[i] =
            exportMap[export.classIndex.asExport].superIndex.resource!.objectName;
      } else if (export.classIndex.isImport) {
        exportType = dataExportTypes[i] =
            importMap[export.classIndex.asImport].objectName;
      } else {
        throw const FormatException("Can't get class name");
      }

      if (exportType.string == 'BlueprintGeneratedClass') continue;

      loader.position = export.serialOffset - packageFileSummary.totalHeaderSize;
      switch (exportType.string) {
        case 'Texture2D':
          dataExports[i] = UTexture2D.read(this, bulk, maxSerial);
        default:
          dataExports[i] = UObject(this, maxSerial);
      }
    }
  }

  final PakBinaryReader _uassetReader;
  late PakBinaryReader loader;

  late FPackageFileSummary packageFileSummary;
  late List<FNameEntrySerialized> nameMap;
  late List<FObjectImport> importMap;
  late List<FObjectExport> exportMap;
  late List<UObject?> dataExports;
  late List<FName> dataExportTypes;

  List<FNameEntrySerialized> _serializeNameMap() {
    if (packageFileSummary.nameCount <= 0) return const [];
    _uassetReader.position = packageFileSummary.nameOffset;
    return [
      for (var i = 0; i < packageFileSummary.nameCount; i++)
        FNameEntrySerialized.read(_uassetReader)
    ];
  }

  List<FObjectImport> _serializeImportMap() {
    if (packageFileSummary.importCount <= 0) return const [];
    _uassetReader.position = packageFileSummary.importOffset;
    return [
      for (var i = 0; i < packageFileSummary.importCount; i++)
        FObjectImport.read(this)
    ];
  }

  List<FObjectExport> _serializeExportMap() {
    if (packageFileSummary.exportCount <= 0) return const [];
    _uassetReader.position = packageFileSummary.exportOffset;
    return [
      for (var i = 0; i < packageFileSummary.exportCount; i++)
        FObjectExport.read(this)
    ];
  }

  FName readFName() {
    final nameIndex = loader.readInt32();
    final number = loader.readInt32();
    if (nameIndex >= 0 && nameIndex < nameMap.length) {
      return FName(nameMap[nameIndex].name, nameIndex, number);
    }
    return const FName.empty();
  }

  // BinaryReader pass-throughs used by the object readers.
  int readUint8() => loader.readUint8();
  int readInt8() => loader.readInt8();
  int readInt16() => loader.readInt16();
  int readUInt16() => loader.readUInt16();
  int readInt32() => loader.readInt32();
  int readUInt32() => loader.readUInt32();
  int readInt64() => loader.readInt64();
  int readUInt64() => loader.readUInt64();
  double readFloat() => loader.readFloat();
  double readDouble() => loader.readDouble();
  Uint8List readBytes(int count) => loader.readBytes(count);
  String? readFString() => loader.readFString();
  List<T> readTArray<T>(T Function() getter) => loader.readTArray(getter);

  int get position => loader.position;
  set position(int value) => loader.position = value;
}

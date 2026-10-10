import 'package_reader.dart';
import 'binary_reader.dart';
import 'objects.dart';

/// Ported subset of `Parsers/Objects/*` needed to read .uasset headers and
/// exports.

class FNameEntrySerialized {
  FNameEntrySerialized(this.name);

  FNameEntrySerialized.read(PakBinaryReader reader)
      : name = reader.readFString() ?? '' {
    reader.skip(4); // DummyHashes
  }

  final String name;

  @override
  String toString() => name;
}

class FName {
  const FName(this.string, [this.index = 0, this.number = 0]);
  const FName.empty()
      : string = '',
        index = 0,
        number = 0;

  final String string;
  final int index;
  final int number;

  bool get isNone => string == 'None';

  @override
  String toString() => string;
}

class FPackageIndex {
  FPackageIndex.read(PackageReader reader)
      : index = reader.readInt32(),
        _reader = reader;

  final int index;
  final PackageReader _reader;

  bool get isNull => index == 0;
  bool get isImport => index < 0;
  bool get isExport => index > 0;
  int get asImport => -index - 1;
  int get asExport => index - 1;

  FObjectResource? get resource {
    if (isNull) return null;
    if (isImport && asImport < _reader.importMap.length) {
      return _reader.importMap[asImport];
    }
    if (isExport && asExport < _reader.exportMap.length) {
      return _reader.exportMap[asExport];
    }
    return null;
  }
}

class FObjectResource {
  FName objectName = const FName.empty();
  FPackageIndex? outerIndex;
}

class FObjectImport extends FObjectResource {
  FObjectImport.read(PackageReader reader) {
    classPackage = reader.readFName();
    className = reader.readFName();
    outerIndex = FPackageIndex.read(reader);
    objectName = reader.readFName();
  }

  late FName classPackage;
  late FName className;
}

class FObjectExport extends FObjectResource {
  FObjectExport.read(PackageReader reader) {
    classIndex = FPackageIndex.read(reader);
    superIndex = FPackageIndex.read(reader);
    templateIndex = FPackageIndex.read(reader);
    outerIndex = FPackageIndex.read(reader);
    objectName = reader.readFName();

    objectFlags = reader.readUInt32() & 0xFFFF;

    serialSize = reader.readInt64();
    serialOffset = reader.readInt64();

    bForcedExport = reader.readInt32() != 0;
    bNotForClient = reader.readInt32() != 0;
    bNotForServer = reader.readInt32() != 0;

    packageGuid = FGuid.read(reader.loader);
    packageFlags = reader.readUInt32();

    bNotAlwaysLoadedForEditorGame = reader.readInt32() != 0;
    bIsAsset = reader.readInt32() != 0;

    firstExportDependency = reader.readInt32();
    serializationBeforeSerializationDependencies = reader.readInt32();
    createBeforeSerializationDependencies = reader.readInt32();
    serializationBeforeCreateDependencies = reader.readInt32();
    createBeforeCreateDependencies = reader.readInt32();
  }

  late FPackageIndex classIndex;
  late FPackageIndex superIndex;
  late FPackageIndex templateIndex;
  late int objectFlags;
  late int serialSize;
  late int serialOffset;
  late bool bForcedExport;
  late bool bNotForClient;
  late bool bNotForServer;
  late FGuid packageGuid;
  late int packageFlags;
  late bool bNotAlwaysLoadedForEditorGame;
  late bool bIsAsset;
  late int firstExportDependency;
  late int serializationBeforeSerializationDependencies;
  late int createBeforeSerializationDependencies;
  late int serializationBeforeCreateDependencies;
  late int createBeforeCreateDependencies;
}

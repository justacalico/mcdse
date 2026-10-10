import 'objects.dart';
import 'package_objects.dart';
import 'package_reader.dart';

/// Ported from `Parsers/Objects/FPropertyTag.cs`.
class FPropertyTag {
  FPropertyTag.read(PackageReader reader) {
    name = reader.readFName();
    if (name.isNone || name.string.isEmpty) {
      return;
    }
    type = reader.readFName();
    size = reader.readInt32();
    arrayIndex = reader.readInt32();
    position = reader.position;
    if (type.number == 0) {
      switch (type.string) {
        case 'StructProperty':
          structName = reader.readFName();
          structGuid = FGuid.read(reader.loader);
        case 'BoolProperty':
          boolVal = reader.readUint8();
        case 'ByteProperty':
        case 'EnumProperty':
          enumName = reader.readFName();
        case 'ArrayProperty':
        case 'SetProperty':
          innerType = reader.readFName();
        case 'MapProperty':
          innerType = reader.readFName();
          valueType = reader.readFName();
      }
    }
    hasPropertyGuid = reader.readUint8();
    if (hasPropertyGuid != 0) {
      propertyGuid = FGuid.read(reader.loader);
    }
  }

  /// Default/empty tag used for array element dispatch.
  FPropertyTag.empty()
      : name = const FName.empty(),
        type = const FName.empty(),
        size = 0,
        arrayIndex = 0,
        position = 0,
        boolVal = 0,
        enumName = const FName.empty(),
        innerType = const FName.empty(),
        valueType = const FName.empty(),
        structName = const FName.empty(),
        hasPropertyGuid = 0;

  FName name = const FName.empty();
  FName type = const FName.empty();
  int size = 0;
  int arrayIndex = 0;
  int position = 0;
  int boolVal = 0;
  FName enumName = const FName.empty();
  FName innerType = const FName.empty();
  FName valueType = const FName.empty();
  FName structName = const FName.empty();
  FGuid? structGuid;
  int hasPropertyGuid = 0;
  FGuid? propertyGuid;
}

enum ReadType { normal, map, array }

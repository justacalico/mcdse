import 'objects.dart';
import 'package_objects.dart';
import 'package_reader.dart';
import 'property_tag.dart';

/// Ported from `Parsers/Class/UObject.cs`.
///
/// Reads the tagged property list of a cooked export. Unknown/unhandled
/// property types are skipped via `tag.size` so the reader stays aligned.
class UObject {
  UObject(PackageReader reader,
      [int? maxSize, this.structFallback = false]) {
    var num = 1;
    while (true) {
      final tag = FPropertyTag.read(reader);
      if (tag.name.isNone || tag.name.string.isEmpty) break;

      final pos = reader.position;
      final obj = readAsObject(reader, tag, tag.type, ReadType.normal);
      final key = properties.containsKey(tag.name.string)
          ? '${tag.name.string}_NK${(num++).toString().padLeft(2, '0')}'
          : tag.name.string;
      properties[key] = obj;
      if (obj == null) break;
      if (tag.size + pos != reader.position) {
        reader.position = tag.size + pos;
      }
    }

    if (!structFallback && reader.readInt32() != 0) {
      if (maxSize == null || reader.position + 16 <= maxSize) {
        FGuid.read(reader.loader);
      }
    }
  }

  /// Fallback constructor signature used by upstream callers:
  /// `UObject(reader)` / `UObject(reader, maxSize)` /
  /// `UObject(reader, maxSize, structFallback)`.
  final Map<String, dynamic> properties = {};

  final bool structFallback;

  dynamic operator [](String key) => properties[key];
  bool containsKey(String key) => properties.containsKey(key);

  /// Reads a property value as a Dart object.
  dynamic readAsObject(
      PackageReader reader, FPropertyTag tag, FName type, ReadType readType) {
    switch (type.string) {
      case 'ByteProperty':
        switch (readType) {
          case ReadType.normal:
            return reader.readFName().index;
          case ReadType.map:
            return reader.readUInt32();
          case ReadType.array:
            return reader.readUint8();
        }
      case 'BoolProperty':
        switch (readType) {
          case ReadType.normal:
            return tag.boolVal != 0;
          case ReadType.map:
          case ReadType.array:
            return reader.readUint8() != 0;
        }
      case 'IntProperty':
        return reader.readInt32();
      case 'FloatProperty':
        return reader.readFloat();
      case 'ObjectProperty':
        return FPackageIndex.read(reader).index;
      case 'NameProperty':
        return reader.readFName().string;
      case 'DelegateProperty':
        // Not implemented upstream either — skipped by size correction.
        return null;
      case 'DoubleProperty':
        return reader.readDouble();
      case 'ArrayProperty':
        return _readArray(reader, tag);
      case 'StructProperty':
        return UScriptStruct.read(reader, tag.structName);
      case 'StrProperty':
        return reader.readFString();
      case 'TextProperty':
        return _readText(reader);
      case 'InterfaceProperty':
        return FPackageIndex.read(reader).index;
      case 'SoftObjectProperty':
        final pos = reader.position;
        final assetPath = reader.readFName().string;
        final subPath = reader.readFString() ?? '';
        if (readType == ReadType.map) {
          // Skip ahead, putting the total bytes read to 16.
          reader.position += 16 - (reader.position - pos);
        }
        return {'AssetPathName': assetPath, 'SubPathString': subPath};
      case 'UInt64Property':
        return reader.readUInt64();
      case 'UInt32Property':
        return reader.readUInt32();
      case 'UInt16Property':
        return reader.readUInt16();
      case 'Int64Property':
        return reader.readInt64();
      case 'Int16Property':
        return reader.readInt16();
      case 'Int8Property':
        return reader.readInt8();
      case 'MapProperty':
        return _readMap(reader, tag);
      case 'SetProperty':
        return _readSet(reader, tag);
      case 'EnumProperty':
        return reader.readFName().string;
      default:
        return null;
    }
  }

  List<dynamic>? _readArray(PackageReader reader, FPropertyTag tag) {
    final length = reader.readInt32();
    var innerTag = FPropertyTag.empty();
    if (tag.innerType.string == 'StructProperty') {
      innerTag = FPropertyTag.read(reader);
    }
    return [
      for (var i = 0; i < length; i++)
        readAsObject(reader, innerTag, tag.innerType, ReadType.array),
    ];
  }

  Map<dynamic, dynamic>? _readMap(PackageReader reader, FPropertyTag tag) {
    final numKeysToRemove = reader.readInt32();
    if (numKeysToRemove != 0) {
      throw UnimplementedError(
          "Parsing of non-zero NumKeysToRemove maps aren't supported yet.");
    }
    final numEntries = reader.readInt32();
    final dict = <dynamic, dynamic>{};
    for (var i = 0; i < numEntries; i++) {
      dict[readAsObject(reader, tag, tag.innerType, ReadType.map)] =
          readAsObject(reader, tag, tag.valueType, ReadType.map);
    }
    return dict;
  }

  List<dynamic>? _readSet(PackageReader reader, FPropertyTag tag) {
    final numKeysToRemove = reader.readInt32();
    if (numKeysToRemove != 0) {
      throw UnimplementedError(
          "Parsing of non-zero NumKeysToRemove sets aren't supported yet.");
    }
    final numEntries = reader.readInt32();
    return [
      for (var i = 0; i < numEntries; i++)
        readAsObject(reader, tag, tag.innerType, ReadType.array),
    ];
  }

  /// Minimal FText reader — enough for cooked packages (reads flags + history
  /// for the common "none/base" case and skips otherwise).
  String? _readText(PackageReader reader) {
    // FText: uint32 flags, sbyte historyType, then history payload.
    reader.readUInt32(); // flags
    final historyType = reader.readInt8();
    switch (historyType) {
      case 0: // None
        reader.readFString(); // culture-invariant string
        return null;
      case -1: // Base
        reader.readFString(); // namespace
        reader.readFString(); // key
        return reader.readFString(); // source string
      default:
        // Rare text history types — bail and let size correction recover.
        return null;
    }
  }
}

/// Ported from `UScriptStruct.cs` — fixed-shape binary structs with a tagged
/// fallback.
class UScriptStruct {
  static dynamic read(PackageReader reader, FName structName) {
    switch (structName.string) {
      case 'Quat':
        return [
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat()
        ];
      case 'Vector4':
        return [
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat()
        ];
      case 'Vector':
        return [
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat()
        ];
      case 'Vector2D':
        return [reader.readFloat(), reader.readFloat()];
      case 'Box2D':
        return [
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat(),
          reader.readUint8(),
        ];
      case 'Box':
        return [
          for (var i = 0; i < 6; i++) reader.readFloat(),
          reader.readUint8()
        ];
      case 'Rotator':
        return [
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat()
        ];
      case 'IntPoint':
        return [reader.readInt32(), reader.readInt32()];
      case 'Guid':
        return FGuid.read(reader.loader);
      case 'SoftObjectPath':
      case 'SoftClassPath':
        return {
          'AssetPathName': reader.readFName().string,
          'SubPathString': reader.readFString() ?? '',
        };
      case 'Color':
        return [
          reader.readUint8(),
          reader.readUint8(),
          reader.readUint8(),
          reader.readUint8()
        ];
      case 'LinearColor':
        return [
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat(),
          reader.readFloat()
        ];
      case 'DateTime':
      case 'Timespan':
        return reader.readUInt64();
      case 'FrameNumber':
      case 'MovieSceneTrackIdentifier':
      case 'MovieSceneSegmentIdentifier':
      case 'MovieSceneSequenceID':
        return reader.readFloat();
      case 'PerPlatformFloat':
        reader.readUint8(); // bCooked
        return reader.readFloat();
      case 'PerPlatformInt':
        reader.readUint8(); // bCooked
        return reader.readInt32();
      case 'SimpleCurveKey':
        return [reader.readFloat(), reader.readFloat()];
      default:
        return UObject(reader, null, true);
    }
  }
}

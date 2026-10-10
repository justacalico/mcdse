import 'dart:typed_data';

import 'package_reader.dart';
import 'uobject.dart';
import 'utexture2d.dart';

/// Ported from `Pak/PakPackage.cs` — lazily parses a .uasset/.uexp pair.
class PakPackage {
  PakPackage(this.uAsset, this.uExp, this.uBulk);

  final Uint8List uAsset;
  final Uint8List uExp;
  final Uint8List? uBulk;

  PackageReader? _reader;

  PackageReader get reader => _reader ??= PackageReader(uAsset, uExp, uBulk);

  List<UObject?> get exports => reader.dataExports;

  bool hasExport() => true;

  UTexture2D? getTexture2D() {
    for (final e in exports) {
      if (e is UTexture2D) return e;
    }
    return null;
  }
}

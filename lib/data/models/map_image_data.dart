import 'static_level_data.dart';

/// Static level map metadata ported from `Data/Models/MapImageData.cs`.
class ColorTuple {
  const ColorTuple(this.a, this.r, this.g, this.b);
  final int a;
  final int r;
  final int g;
  final int b;
}

class RectTuple {
  const RectTuple(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;
}

class MapImageData {
  const MapImageData({
    required this.titleLookupString,
    required this.titleBackupText,
    required this.mapImageSourcePath,
    required this.backgroundColor,
    this.cropToRect,
    required this.levelData,
  });

  final String titleLookupString;
  final String titleBackupText;
  final String mapImageSourcePath;
  final ColorTuple backgroundColor;
  final RectTuple? cropToRect;
  final List<StaticLevelData> levelData;
}

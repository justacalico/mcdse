import '../enums.dart';

/// Static per-level map placement data ported from `StaticLevelData.cs`.
class StaticLevelData {
  const StaticLevelData(
    this.key,
    this.mapPositionX,
    this.mapPositionY,
    this.levelType, {
    this.alwaysAvailable = false,
  });

  final String key;
  final double mapPositionX;
  final double mapPositionY;
  final LevelTypeEnum levelType;
  final bool alwaysAvailable;
}

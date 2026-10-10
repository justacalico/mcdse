import 'dart:math';

/// Ported from `Logic/GameCalculator.cs`.
abstract final class GameCalculator {
  static int enchantmentCostForLevel(int level) {
    if (level == 0) return 0;
    return (level * (level + 1)) ~/ 2;
  }

  static int powerfulEnchantmentCostForLevel(int level) {
    if (level == 0) return 0;
    return (level * (level + 3)) ~/ 2;
  }

  static int levelFromPower(double power) {
    if (power <= 0) return 0;
    return ((max(1, power) - 1 + 0.00001) * 10).floor() + 1;
  }

  static double powerFromLevel(int level) {
    if (level <= 0) return 0;
    return ((max(1, level) - 1) / 10.0) + 1 + 0.00001;
  }

  static int levelForExperience(int xp) {
    final result = (1.0 / 30.0) * (sqrt(3 * xp + 100.0) + 20);
    return result.floor();
  }

  static int experienceForLevel(int level) {
    return 100 * (level - 1) * (3 * level - 1);
  }

  static double characterPowerFromEquippedItemPowers(
      double melee, double armor, double ranged, double slot1, double slot2, double slot3) {
    return (melee + armor + ranged) / 4 + (slot1 + slot2 + slot3) / 12;
  }
}

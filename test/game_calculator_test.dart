import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/logic/game_calculator.dart';
import 'package:mcdse/logic/extensions.dart';
import 'package:mcdse/data/models/item.dart';

void main() {
  group('GameCalculator', () {
    test('enchantment cost - normal (level*(level+1)/2)', () {
      expect(GameCalculator.enchantmentCostForLevel(0), 0);
      expect(GameCalculator.enchantmentCostForLevel(1), 1);
      expect(GameCalculator.enchantmentCostForLevel(2), 3);
      expect(GameCalculator.enchantmentCostForLevel(3), 6);
    });

    test('enchantment cost - powerful (level*(level+3)/2)', () {
      expect(GameCalculator.powerfulEnchantmentCostForLevel(0), 0);
      expect(GameCalculator.powerfulEnchantmentCostForLevel(1), 2);
      expect(GameCalculator.powerfulEnchantmentCostForLevel(2), 5);
      expect(GameCalculator.powerfulEnchantmentCostForLevel(3), 9);
    });

    test('levelFromPower / powerFromLevel round trip', () {
      expect(GameCalculator.levelFromPower(0), 0);
      expect(GameCalculator.levelFromPower(1), 1);
      for (var level = 1; level < 300; level++) {
        final power = GameCalculator.powerFromLevel(level);
        expect(GameCalculator.levelFromPower(power), level,
            reason: 'level $level');
      }
    });

    test('experienceForLevel / levelForExperience', () {
      expect(GameCalculator.experienceForLevel(1), 0);
      expect(GameCalculator.experienceForLevel(2), 500);
      for (var level = 1; level < 200; level++) {
        final xp = GameCalculator.experienceForLevel(level);
        expect(GameCalculator.levelForExperience(xp), level,
            reason: 'level $level xp $xp');
      }
    });

    test('characterPower formula: gear/4 + hotbar/12', () {
      expect(
          GameCalculator.characterPowerFromEquippedItemPowers(
              100, 100, 100, 0, 0, 0),
          75.0);
      expect(
          GameCalculator.characterPowerFromEquippedItemPowers(
              100, 0, 0, 0, 0, 0),
          25.0);
      expect(
          GameCalculator.characterPowerFromEquippedItemPowers(
              0, 0, 0, 60, 60, 60),
          15.0);
    });
  });

  group('Item extensions', () {
    test('level() derives from power', () {
      final item = Item.fromFields(type: 'Sword', power: 1.0);
      expect(item.level(), 1);
      item.power = GameCalculator.powerFromLevel(50);
      expect(item.level(), 50);
    });
  });
}

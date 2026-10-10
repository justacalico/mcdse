import '../data/constants.dart';
import '../data/enums.dart';
import '../data/models/enchantment.dart';
import '../data/models/item.dart';
import '../data/models/profile_save_file.dart';
import '../data/models/progress.dart';
import '../services/databases.dart';
import 'game_calculator.dart';

/// Ports of `Logic/Extensions/*`.

extension EnchantmentExtensions on Enchantment {
  bool isPowerful() => Constants.powerful.contains(id);

  int pointsCost() {
    final lvl = level;
    return isPowerful()
        ? GameCalculator.powerfulEnchantmentCostForLevel(lvl)
        : GameCalculator.enchantmentCostForLevel(lvl);
  }

  int gildedPointsCost() => pointsCost() + level;
}

extension ItemExtensions on Item {
  int level() => GameCalculator.levelFromPower(power);

  int enchantmentPoints() {
    final ench = enchantments;
    if (ench == null) return 0;
    var points = 0;
    for (final enchantment in ench) {
      points += netheriteEnchant != null
          ? enchantment.gildedPointsCost()
          : enchantment.pointsCost();
    }
    return points;
  }

  bool isArtifact() => ItemDatabase.artifacts.contains(type);
  bool isArmor() => ItemDatabase.armor.contains(type);
  bool isMeleeWeapon() => ItemDatabase.meleeWeapons.contains(type);
  bool isRangedWeapon() => ItemDatabase.rangedWeapons.contains(type);

  bool isHotbarItem() {
    final slot = equipmentSlot;
    return slot == EquipmentSlotEnum.hotbarSlot1.jsonName ||
        slot == EquipmentSlotEnum.hotbarSlot2.jsonName ||
        slot == EquipmentSlotEnum.hotbarSlot3.jsonName;
  }

  bool isGearItem() {
    final slot = equipmentSlot;
    return slot == EquipmentSlotEnum.meleeGear.jsonName ||
        slot == EquipmentSlotEnum.armorGear.jsonName ||
        slot == EquipmentSlotEnum.rangedGear.jsonName;
  }
}

extension ProfileExtensions on ProfileSaveFile {
  bool isValid() => items != null;

  Iterable<Item> allItems() =>
      (items ?? const <Item>[]).followedBy(storageChestItems ?? const <Item>[]);

  int level() => GameCalculator.levelForExperience(xp);

  int remainingEnchantmentPoints() {
    var totalEnchantmentPointsUsed = 1;
    for (final item in allItems()) {
      totalEnchantmentPointsUsed += item.enchantmentPoints();
    }
    return level() - totalEnchantmentPointsUsed;
  }

  Item? _equipmentSlot(EquipmentSlotEnum slot) {
    final slotName = slot.jsonName;
    final list = items;
    if (list == null) return null;
    for (final item in list) {
      if (item.equipmentSlot == slotName) return item;
    }
    return null;
  }

  int computeCharacterPower() {
    final melee = _equipmentSlot(EquipmentSlotEnum.meleeGear)?.power ?? 0;
    final armor = _equipmentSlot(EquipmentSlotEnum.armorGear)?.power ?? 0;
    final ranged = _equipmentSlot(EquipmentSlotEnum.rangedGear)?.power ?? 0;
    final slot1 = _equipmentSlot(EquipmentSlotEnum.hotbarSlot1)?.power ?? 0;
    final slot2 = _equipmentSlot(EquipmentSlotEnum.hotbarSlot2)?.power ?? 0;
    final slot3 = _equipmentSlot(EquipmentSlotEnum.hotbarSlot3)?.power ?? 0;
    final characterPower = GameCalculator.characterPowerFromEquippedItemPowers(
        melee, armor, ranged, slot1, slot2, slot3);
    return GameCalculator.levelFromPower(characterPower);
  }
}

extension ProgressExtensions on Progress {
  int getDifficultyImageLevel() {
    if (completedDifficulty == DifficultyEnum.difficulty1.jsonName) {
      return 2;
    } else if (completedDifficulty == DifficultyEnum.difficulty2.jsonName) {
      return 3;
    } else if (completedDifficulty == DifficultyEnum.difficulty3.jsonName &&
        completedEndlessStruggle <= 0) {
      return 4;
    } else if (completedDifficulty == DifficultyEnum.difficulty3.jsonName &&
        completedEndlessStruggle > 0) {
      return 5;
    }
    return 1;
  }
}

extension IterableItemExtensions on Iterable<Item> {
  /// Returns a new collection with [item] removed.
  List<Item> removing(Item item) => where((e) => !identical(e, item)).toList();

  /// Returns a new collection with [oldValue] replaced by [newValue].
  List<Item> replacing(Item oldValue, Item newValue) {
    final list = toList();
    final index = list.indexOf(oldValue);
    if (index < 0) {
      // Upstream `replacingAtIndex` throws on a missing item — surface
      // stale-selection bugs instead of silently no-oping.
      throw StateError('oldValue not found in collection');
    }
    list.removeAt(index);
    list.insert(index, newValue);
    return list;
  }

  List<Item> adding(Item item) => [...this, item];
}

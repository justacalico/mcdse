/// Enums ported from MCDSaveEdit's `Data/Enums/*`.
library;

enum DifficultyEnum {
  difficulty1('Difficulty_1', 1),
  difficulty2('Difficulty_2', 2),
  difficulty3('Difficulty_3', 3);

  const DifficultyEnum(this.jsonName, this.value);
  final String jsonName;
  final int value;

  static DifficultyEnum? fromJsonName(String? name) {
    for (final d in values) {
      if (d.jsonName == name) return d;
    }
    return null;
  }
}

enum EquipmentSlotEnum {
  meleeGear('MeleeGear'),
  armorGear('ArmorGear'),
  rangedGear('RangedGear'),
  hotbarSlot1('HotbarSlot1'),
  hotbarSlot2('HotbarSlot2'),
  hotbarSlot3('HotbarSlot3');

  const EquipmentSlotEnum(this.jsonName);
  final String jsonName;
}

enum ItemFilterEnum { all, meleeWeapons, rangedWeapons, armor, artifacts, enchanted }

enum ItemLocationEnum { inventory, chest, tower }

enum LevelTypeEnum { mission, dungeon }

enum Rarity {
  common('Common'),
  rare('Rare'),
  unique('Unique');

  const Rarity(this.jsonName);
  final String jsonName;

  static Rarity fromJsonName(String? name) {
    for (final r in values) {
      if (r.jsonName == name) return r;
    }
    return Rarity.common;
  }
}

enum ThreatLevelEnum {
  threat1,
  threat2,
  threat3,
  threat4,
  threat5,
  threat6,
  threat7,
}

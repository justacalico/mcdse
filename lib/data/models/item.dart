import '../enums.dart';
import 'armor_property.dart';
import 'enchantment.dart';

/// Save-file item model. Wraps the raw JSON map so every field round-trips
/// verbatim, while exposing typed accessors for the fields the editor uses.
class Item {
  Item([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  Item.fromFields({
    List<ArmorProperty>? armorProperties,
    bool? cloned,
    List<Enchantment>? enchantments,
    String? equipmentSlot,
    bool? gifted,
    int? inventoryIndex,
    bool? modified,
    bool? markedNew,
    Enchantment? netheriteEnchant,
    double power = 0,
    Rarity rarity = Rarity.common,
    int? timesModified,
    String type = '',
    bool? upgraded,
  }) : json = <String, dynamic>{
          if (armorProperties != null)
            'armorproperties': [for (final p in armorProperties) p.json],
          if (cloned != null) 'cloned': cloned,
          if (enchantments != null)
            'enchantments': [for (final e in enchantments) e.json],
          if (equipmentSlot != null) 'equipmentSlot': equipmentSlot,
          if (gifted != null) 'gifted': gifted,
          if (inventoryIndex != null) 'inventoryIndex': inventoryIndex,
          if (modified != null) 'modified': modified,
          if (markedNew != null) 'markedNew': markedNew,
          if (netheriteEnchant != null) 'netheriteEnchant': netheriteEnchant.json,
          'power': power,
          'rarity': rarity.jsonName,
          if (timesModified != null) 'timesmodified': timesModified,
          'type': type,
          if (upgraded != null) 'upgraded': upgraded,
        };

  final Map<String, dynamic> json;

  List<ArmorProperty>? get armorProperties => _armorList();
  set armorProperties(List<ArmorProperty>? value) =>
      json['armorproperties'] =
          value == null ? null : [for (final p in value) p.json];

  List<ArmorProperty>? _armorList() {
    final raw = json['armorproperties'];
    if (raw is! List) return null;
    return [for (final e in raw) ArmorProperty(e as Map<String, dynamic>)];
  }

  bool? get cloned => json['cloned'] as bool?;
  set cloned(bool? v) => json['cloned'] = v;

  List<Enchantment>? get enchantments => _enchantmentList();
  set enchantments(List<Enchantment>? value) =>
      json['enchantments'] =
          value == null ? null : [for (final e in value) e.json];

  List<Enchantment>? _enchantmentList() {
    final raw = json['enchantments'];
    if (raw is! List) return null;
    return [for (final e in raw) Enchantment(e as Map<String, dynamic>)];
  }

  String? get equipmentSlot => json['equipmentSlot'] as String?;
  set equipmentSlot(String? v) => json['equipmentSlot'] = v;

  bool? get gifted => json['gifted'] as bool?;
  set gifted(bool? v) => json['gifted'] = v;

  int? get inventoryIndex => (json['inventoryIndex'] as num?)?.toInt();
  set inventoryIndex(int? v) => json['inventoryIndex'] = v;

  bool? get modified => json['modified'] as bool?;
  set modified(bool? v) => json['modified'] = v;

  bool? get markedNew => json['markedNew'] as bool?;
  set markedNew(bool? v) => json['markedNew'] = v;

  Enchantment? get netheriteEnchant {
    final raw = json['netheriteEnchant'];
    if (raw is! Map<String, dynamic>) return null;
    return Enchantment(raw);
  }

  set netheriteEnchant(Enchantment? v) => json['netheriteEnchant'] = v?.json;

  double get power => (json['power'] as num?)?.toDouble() ?? 0;
  set power(double v) => json['power'] = v;

  Rarity get rarity => Rarity.fromJsonName(json['rarity'] as String?);
  set rarity(Rarity v) => json['rarity'] = v.jsonName;

  int? get timesModified => (json['timesmodified'] as num?)?.toInt();
  set timesModified(int? v) => json['timesmodified'] = v;

  String get type => json['type'] as String? ?? '';
  set type(String v) => json['type'] = v;

  bool? get upgraded => json['upgraded'] as bool?;
  set upgraded(bool? v) => json['upgraded'] = v;

  /// Deep copy. Deliberately skips equipmentSlot and inventoryIndex,
  /// matching upstream `Item.Copy()`.
  Item copy() {
    return Item.fromFields(
      armorProperties: armorProperties?.map((p) => p.copy()).toList(),
      enchantments: enchantments?.map((e) => e.copy()).toList(),
      gifted: gifted,
      markedNew: markedNew,
      netheriteEnchant: netheriteEnchant?.copy(),
      power: power,
      rarity: rarity,
      type: type,
      upgraded: upgraded,
    );
  }
}

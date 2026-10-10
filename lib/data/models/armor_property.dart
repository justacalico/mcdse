import '../enums.dart';

/// Save-file armor property model (map-backed).
class ArmorProperty {
  ArmorProperty([Map<String, dynamic>? json]) : json = json ?? <String, dynamic>{};

  ArmorProperty.fromFields({String id = '', Rarity rarity = Rarity.common})
      : json = <String, dynamic>{'id': id, 'rarity': rarity.jsonName};

  final Map<String, dynamic> json;

  String get id => json['id'] as String? ?? '';
  set id(String v) => json['id'] = v;

  Rarity get rarity => Rarity.fromJsonName(json['rarity'] as String?);
  set rarity(Rarity v) => json['rarity'] = v.jsonName;

  ArmorProperty copy() => ArmorProperty.fromFields(id: id, rarity: rarity);
}

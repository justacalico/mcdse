import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/data/profile_parser.dart';
import 'package:mcdse/viewmodels/item_list_view_model.dart';
import 'package:mcdse/data/models/item.dart';
import 'package:mcdse/data/enums.dart';
import 'package:mcdse/data/constants.dart';

void main() {
  group('ProfileParser sanitization', () {
    test('strips control characters', () {
      final p = ProfileParser.read(utf8.encode('{"items":[]\x00\x01}'));
      expect(p, isNotNull);
      expect(p!.items, isEmpty);
    });

    test('truncates after first complete JSON object (PS4 dup data)', () {
      const json1 = '{"items":[{"inventoryIndex":0}],"xp":100}';
      const dup = '$json1$json1';
      final p = ProfileParser.read(utf8.encode(dup));
      expect(p, isNotNull);
      expect(p!.items!.length, 1);
      expect(p.xp, 100);
    });

    test('returns null on garbage', () {
      // Non-JSON input throws (upstream's MainViewModel catches and shows
      // the unexpected-format error); non-object JSON returns null.
      expect(() => ProfileParser.read(utf8.encode('not json')),
          throwsFormatException);
      expect(() => ProfileParser.read(utf8.encode('')),
          throwsFormatException);
      expect(ProfileParser.read(utf8.encode('123')), isNull);
    });

    test('round-trips JSON preserving unknown fields', () {
      const json = '{"items":[],"customField":42,"nested":{"a":[1,2,3]}}';
      final p = ProfileParser.read(utf8.encode(json))!;
      final out = jsonEncode(p.json);
      final decoded = jsonDecode(out);
      expect(decoded['customField'], 42);
      expect(decoded['nested'], {'a': [1, 2, 3]});
    });
  });

  group('Item model', () {
    test('toJson preserves all fields', () {
      final item = Item.fromFields(
          type: 'Sword',
          power: 10,
          rarity: Rarity.unique,
          equipmentSlot: EquipmentSlotEnum.meleeGear.jsonName,
          inventoryIndex: 3,
          markedNew: true,
          upgraded: true,
          gifted: true);
      final j = item.json;
      expect(j['type'], 'Sword');
      expect(j['power'], 10);
      expect(j['rarity'], 'Unique');
      expect(j['equipmentSlot'], 'MeleeGear');
      expect(j['inventoryIndex'], 3);
      expect(j['markedNew'], true);
      expect(j['upgraded'], true);
      expect(j['gifted'], true);
    });

    test('copy produces independent duplicate', () {
      final item = Item.fromFields(type: 'Sword', power: 10);
      final copy = item.copy();
      copy.power = 99;
      copy.type = 'Bow';
      expect(item.power, 10);
      expect(item.type, 'Sword');
    });

    test('createDefaultItemForFilter', () {
      final melee = Constants.createDefaultItemForFilter(
          ItemFilterEnum.meleeWeapons);
      expect(melee.type, Constants.defaultMeleeWeaponId);
      expect(melee.rarity, Rarity.common);
      final armor =
          Constants.createDefaultItemForFilter(ItemFilterEnum.armor);
      expect(armor.type, Constants.defaultArmorId);
      // Upstream does not pre-create armor properties on new items.
      expect(armor.armorProperties, isNull);
    });

    test('createDefaultItemForEquipmentSlot sets slot', () {
      final item = Constants.createDefaultItemForEquipmentSlot(
          EquipmentSlotEnum.hotbarSlot2);
      expect(item.equipmentSlot, 'HotbarSlot2');
    });
  });

  group('ItemListViewModel helpers', () {
    test('equipmentSlotItem finds matching slot', () {
      final sword = Item.fromFields(
          type: 'Sword',
          equipmentSlot: EquipmentSlotEnum.meleeGear.jsonName);
      final bow = Item.fromFields(
          type: 'Bow',
          equipmentSlot: EquipmentSlotEnum.rangedGear.jsonName);
      expect(
          ItemListViewModel.equipmentSlotItem(
              [sword, bow], EquipmentSlotEnum.rangedGear),
          bow);
      expect(
          ItemListViewModel.equipmentSlotItem(
              [sword, bow], EquipmentSlotEnum.armorGear),
          isNull);
    });
  });
}

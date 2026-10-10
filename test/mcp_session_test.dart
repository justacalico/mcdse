import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/mcp/save_session.dart';
import 'package:mcdse/services/databases.dart';

const _blankDat =
    '/mnt/other/devinoruim-projects/MCDSaveEdit-upstream/MCDSaveEditTests/TestData/Blank.dat';

Directory _tmpDir() => Directory.systemTemp.createTempSync('mcdse_mcp_test');

File _jsonSave(Directory dir) {
  final f = File('${dir.path}/char.json');
  f.writeAsStringSync(jsonEncode({
    'items': [
      {'type': 'Sword', 'power': 5.0, 'rarity': 'Common', 'equipmentSlot': 'MeleeGear', 'inventoryIndex': 0},
      {'type': 'Bow', 'power': 4.0, 'rarity': 'Rare', 'inventoryIndex': 1},
    ],
    'storageChestItems': [
      {'type': 'FishingRod', 'power': 1.0, 'rarity': 'Common', 'inventoryIndex': 0},
    ],
    'currency': [
      {'type': 'Emerald', 'count': 23},
    ],
    'xp': 718,
  }));
  return f;
}

void main() {
  late Directory dir;
  late File jsonFile;

  setUp(() {
    dir = _tmpDir();
    jsonFile = _jsonSave(dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('open .json save and read info', () async {
    final s = SaveSession();
    final info = await s.open(jsonFile.path);
    expect(info['level'], 2);
    expect(info['xp'], 718);
    expect(info['currencies']['Emerald'], 23);
    expect(info['inventoryItemCount'], 2);
    expect(info['storageChestItemCount'], 1);
    expect(info['equippedItems']['MeleeGear'], 'Sword');
  });

  test('open encrypted .dat save', () async {
    final s = SaveSession();
    final copy = File('${dir.path}/blank.dat')..writeAsBytesSync(File(_blankDat).readAsBytesSync());
    final info = await s.open(copy.path);
    expect(info['inventoryItemCount'], 0);
  });

  test('open nonexistent file throws', () {
    final s = SaveSession();
    expect(() => s.open('${dir.path}/nope.dat'), throwsArgumentError);
  });

  test('reads before open throw StateError', () {
    final s = SaveSession();
    expect(() => s.info(), throwsStateError);
    expect(() => s.listItems('inventory'), throwsStateError);
  });

  test('list/get/update item', () async {
    final s = SaveSession();
    await s.open(jsonFile.path);
    final items = s.listItems('inventory');
    expect(items, hasLength(2));
    expect(items[0]['type'], 'Sword');
    final updated = s.updateItem(0, 'inventory', {'power': 263.5, 'rarity': 'Unique', 'gifted': true});
    expect(updated['power'], 263.5);
    expect(updated['rarity'], 'Unique');
    expect(updated['gifted'], true);
    expect(() => s.updateItem(0, 'inventory', {'xp': 1}), throwsArgumentError);
    expect(() => s.getItem(99, 'inventory'), throwsArgumentError);
  });

  test('add item assigns next inventoryIndex and evicts gear slot', () async {
    final s = SaveSession();
    await s.open(jsonFile.path);
    final added = s.addItem(
        type: 'Battlestaff', power: 108.5, rarity: 'Unique',
        equipmentSlot: 'MeleeGear');
    expect(added['inventoryIndex'], 2);
    // Sword held MeleeGear — upstream evicts it.
    final items = s.listItems('inventory');
    expect(items.any((i) => i['type'] == 'Sword'), false);
    expect(items.singleWhere((i) => i['type'] == 'Battlestaff')['equipmentSlot'],
        'MeleeGear');
  });

  test('duplicate + move + remove', () async {
    final s = SaveSession();
    await s.open(jsonFile.path);
    s.duplicateItem(1, 'inventory');
    expect(s.listItems('inventory'), hasLength(3));
    final moved = s.moveItem(1, 'inventory');
    expect(moved['movedTo'], 'chest');
    expect(s.listItems('inventory'), hasLength(2));
    expect(s.listItems('chest'), hasLength(2));
    s.removeItem(0, 'chest');
    expect(s.listItems('chest'), hasLength(1));
  });

  test('set currency creates missing types and updates existing', () async {
    final s = SaveSession();
    await s.open(jsonFile.path);
    expect(s.setCurrency('Emerald', 9999)['count'], 9999);
    expect(s.setCurrency('Gold', 7)['type'], 'Gold');
    expect(s.info()['currencies']['Gold'], 7);
  });

  test('set level writes xp', () async {
    final s = SaveSession();
    await s.open(jsonFile.path);
    final r = s.setLevel(50);
    expect(r['level'], 50);
    expect(r['xp'], greaterThan(0));
    expect(s.setXp(718)['level'], 2);
  });

  test('save .json persists edits on reopen', () async {
    final s = SaveSession();
    await s.open(jsonFile.path);
    s.addItem(type: 'Axe', power: 50);
    s.setCurrency('Emerald', 7777);
    await s.save();

    final s2 = SaveSession();
    final info = await s2.open(jsonFile.path);
    expect(info['inventoryItemCount'], 3);
    expect(info['currencies']['Emerald'], 7777);
    expect(s2.listItems('inventory').any((i) => i['type'] == 'Axe'), true);
  });

  test('save .dat encrypts and round-trips', () async {
    final s = SaveSession();
    await s.open(jsonFile.path);
    s.addItem(type: 'Glaive', power: 120);
    final datPath = '${dir.path}/out.dat';
    await s.save(datPath);
    final bytes = File(datPath).readAsBytesSync();
    expect(bytes.sublist(0, 4), [0x44, 0x30, 0x30, 0x31]); // D001 magic

    final s2 = SaveSession();
    await s2.open(datPath);
    expect(s2.listItems('inventory').any((i) => i['type'] == 'Glaive'), true);
  });

  test('catalog exposes ids, limits and rules', () {
    ItemDatabase.meleeWeapons.addAll(['Axe', 'Sword']);
    ItemDatabase.armorProperties.add('ChillingFocus');
    EnchantmentDatabase.allEnchantments.addAll(['Sharpness', 'Chilling']);
    addTearDown(() {
      ItemDatabase.meleeWeapons.clear();
      ItemDatabase.armorProperties.clear();
      EnchantmentDatabase.allEnchantments.clear();
    });

    final s = SaveSession();
    final cat = s.catalog();
    expect(cat['itemTypes']['melee'], ['Axe', 'Sword']);
    final enchants = cat['enchantments'] as List;
    expect(enchants.singleWhere((e) => e['id'] == 'Chilling')['powerful'], true);
    expect(enchants.singleWhere((e) => e['id'] == 'Sharpness')['powerful'], false);
    expect(cat['armorProperties'].single['id'], 'ChillingFocus');
    expect(cat['equipmentSlots']['MeleeGear'], 'meleeGear');
    expect(cat['rarities'], containsAll(['Common', 'Rare', 'Unique']));
    expect(cat['limits']['maxInventoryItems'], 300);
    expect(cat['saveFormat']['rules'], isNotEmpty);
  });

  test('onChanged fires on open and every mutation', () async {
    final s = SaveSession();
    var calls = 0;
    s.onChanged = () => calls++;
    await s.open(jsonFile.path);
    s.addItem(type: 'Axe');
    s.updateItem(0, 'inventory', {'power': 9.0});
    s.duplicateItem(0, 'inventory');
    s.moveItem(0, 'inventory');
    s.removeItem(0, 'inventory');
    s.setCurrency('Emerald', 5);
    s.setLevel(10);
    s.setXp(1);
    await s.save();
    expect(calls, 10);
  });

  group('catalog validation', () {
    setUp(() {
      ItemDatabase.all.addAll(['Axe', 'Sword', 'Bow', 'WitherArmor', 'FishingRod']);
      ItemDatabase.meleeWeapons.addAll(['Axe', 'Sword']);
      ItemDatabase.rangedWeapons.add('Bow');
      ItemDatabase.armor.add('WitherArmor');
      ItemDatabase.artifacts.add('FishingRod');
      ItemDatabase.armorProperties.add('ChillingFocus');
      EnchantmentDatabase.allEnchantments.addAll(['Sharpness', 'Chilling']);
    });
    tearDown(() {
      ItemDatabase.all.clear();
      ItemDatabase.meleeWeapons.clear();
      ItemDatabase.rangedWeapons.clear();
      ItemDatabase.armor.clear();
      ItemDatabase.artifacts.clear();
      ItemDatabase.armorProperties.clear();
      EnchantmentDatabase.allEnchantments.clear();
    });

    test('rejects nonexistent item types', () async {
      final s = SaveSession();
      await s.open(jsonFile.path);
      expect(() => s.addItem(type: 'NotARealSword'), throwsArgumentError);
      expect(s.addItem(type: 'Axe')['type'], 'Axe');
    });

    test('rejects wrong-category equipment slots', () async {
      final s = SaveSession();
      await s.open(jsonFile.path);
      expect(
          () => s.addItem(type: 'Bow', equipmentSlot: 'MeleeGear'),
          throwsArgumentError);
      expect(() => s.addItem(type: 'Bow', equipmentSlot: 'NopeSlot'),
          throwsArgumentError);
      expect(s.addItem(type: 'Bow', equipmentSlot: 'RangedGear')['type'],
          'Bow');
    });

    test('rejects bad rarity, power, enchants, armor properties', () async {
      final s = SaveSession();
      await s.open(jsonFile.path);
      expect(() => s.addItem(type: 'Axe', rarity: 'Mythic'),
          throwsArgumentError);
      expect(() => s.addItem(type: 'Axe', power: 0), throwsArgumentError);
      expect(
          () => s.addItem(type: 'Axe', enchantments: [
                {'id': 'FakeEnchant', 'level': 1}
              ]),
          throwsArgumentError);
      expect(
          () => s.addItem(type: 'Axe', enchantments: [
                {'id': 'Sharpness', 'level': 9}
              ]),
          throwsArgumentError);
      expect(
          () => s.addItem(type: 'WitherArmor', armorProperties: [
                {'id': 'FakeProp'}
              ]),
          throwsArgumentError);
      // Valid forms pass.
      s.addItem(type: 'Axe', enchantments: [
        {'id': 'Sharpness', 'level': 3}
      ], netheriteEnchant: {'id': 'Chilling', 'level': 1});
      s.addItem(type: 'WitherArmor', armorProperties: [
        {'id': 'ChillingFocus'}
      ]);
    });

    test('update_item validates merged result', () async {
      final s = SaveSession();
      await s.open(jsonFile.path);
      expect(() => s.updateItem(0, 'inventory', {'type': 'NotReal'}),
          throwsArgumentError);
      expect(() => s.updateItem(0, 'inventory', {'rarity': 'God'}),
          throwsArgumentError);
      expect(
          () => s.updateItem(0, 'inventory', {
                'enchantments': [
                  {'id': 'Bogus', 'level': 1}
                ]
              }),
          throwsArgumentError);
      final ok = s.updateItem(0, 'inventory', {'type': 'Axe', 'rarity': 'Unique'});
      expect(ok['type'], 'Axe');
    });

    test('level bounds enforced', () async {
      final s = SaveSession();
      await s.open(jsonFile.path);
      expect(() => s.setLevel(0), throwsArgumentError);
      expect(s.setLevel(999)['level'], 999);
    });
  });

  test('dump_profile_json returns full map', () async {
    final s = SaveSession();
    await s.open(jsonFile.path);
    final dumped = jsonDecode(s.dumpJson()) as Map<String, dynamic>;
    expect(dumped['xp'], 718);
    expect(dumped['items'], hasLength(2));
  });
}

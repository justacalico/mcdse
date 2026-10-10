import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../data/constants.dart';
import '../data/enums.dart';
import '../data/models/armor_property.dart';
import '../data/models/enchantment.dart';
import '../data/models/currency.dart';
import '../data/models/item.dart';
import '../data/models/profile_save_file.dart';
import '../data/profile_parser.dart';
import '../logic/extensions.dart';
import '../logic/file_process_helper.dart';
import '../logic/game_calculator.dart';
import '../services/databases.dart';
import '../services/save_file_handler.dart';
import '../services/string_library.dart';

/// Single-save session backing the MCP server tools. All read methods return
/// JSON-friendly maps/lists; mutation methods mutate the in-memory profile
/// until [save] is called.
class SaveSession {
  String? filePath;
  ProfileSaveFile? profile;

  /// Fired after [open] and every successful mutation / [save] — the app
  /// host uses it to refresh the UI.
  void Function()? onChanged;

  bool get isOpen => profile != null;

  void _changed() => onChanged?.call();

  void _requireOpen() {
    if (profile == null) {
      throw StateError('No save file is open. Call open_save first.');
    }
  }

  List<String> detectedSaveFiles() =>
      [for (final f in Constants.detectedSaveFiles()) f.path];

  Future<Map<String, dynamic>> open(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw ArgumentError('File does not exist: $path');
    }
    final bytes = await file.readAsBytes();
    List<int> jsonBytes;
    if (path.endsWith(Constants.decryptedFileExtension)) {
      jsonBytes = bytes;
    } else {
      if (!SaveFileHandler.isFileEncrypted(bytes)) {
        throw ArgumentError(
            'File is not in the encrypted .dat format and is not a .json file.');
      }
      final decrypted = await FileProcessHelper.decrypt(bytes);
      if (decrypted == null) {
        throw ArgumentError('Failed to decrypt save file.');
      }
      jsonBytes = decrypted;
    }
    final parsed = ProfileParser.read(Uint8List.fromList(jsonBytes));
    if (parsed == null || !parsed.isValid()) {
      throw ArgumentError('File is not a recognized character save.');
    }
    filePath = path;
    profile = parsed;
    _changed();
    return info();
  }

  Map<String, dynamic> info() {
    _requireOpen();
    final p = profile!;
    final inv = p.items ?? const <Item>[];
    final chest = p.storageChestItems ?? const <Item>[];
    return {
      'filePath': filePath,
      'level': GameCalculator.levelForExperience(p.xp),
      'xp': p.xp,
      'characterPower': p.computeCharacterPower(),
      'currencies': {
        for (final c in p.currency ?? const <Currency>[]) c.type: c.count,
      },
      'inventoryItemCount': inv.length,
      'storageChestItemCount': chest.length,
      'equippedItems': {
        for (final item in inv)
          if (item.equipmentSlot != null) item.equipmentSlot!: item.type,
      },
    };
  }

  List<Item> _listFor(String location) {
    _requireOpen();
    switch (location) {
      case 'inventory':
        return profile!.items ??= <Item>[];
      case 'chest':
        return profile!.storageChestItems ??= <Item>[];
      default:
        throw ArgumentError(
            'location must be "inventory" or "chest", got "$location"');
    }
  }

  /// Re-syncs the wrapped list back into the raw profile JSON — the `items`
  /// setters serialize each `Item.json`, which plain `list.add` bypasses.
  void _commit(String location, List<Item> items) {
    if (location == 'inventory') {
      profile!.items = items;
    } else {
      profile!.storageChestItems = items;
    }
  }

  List<Map<String, dynamic>> listItems(String location) {
    final items = location == 'all'
        ? [..._listFor('inventory'), ..._listFor('chest')]
        : _listFor(location);
    return [
      for (var i = 0; i < items.length; i++)
        {'index': i, 'location': location == 'all' ? _locationOf(items[i]) : location, ...items[i].json},
    ];
  }

  String _locationOf(Item item) =>
      (profile!.storageChestItems ?? const <Item>[]).any((i) => identical(i, item))
          ? 'chest'
          : 'inventory';

  Map<String, dynamic> getItem(int index, String location) {
    final items = _listFor(location);
    if (index < 0 || index >= items.length) {
      throw ArgumentError('index $index out of range (0..${items.length - 1})');
    }
    return items[index].json;
  }

  /// Validates an item spec against the loaded game catalog. When no game
  /// content is loaded (standalone server without paks) checks that don't
  /// need the catalog still apply.
  List<String> _itemErrors({
    required String type,
    String? equipmentSlot,
    String? rarity,
    double? power,
    List<Map<String, dynamic>>? enchantments,
    Map<String, dynamic>? netheriteEnchant,
    List<Map<String, dynamic>>? armorProperties,
  }) {
    final errors = <String>[];
    final hasCatalog = ItemDatabase.all.isNotEmpty;
    if (hasCatalog && !ItemDatabase.all.contains(type)) {
      errors.add('unknown item type "$type" — valid ids are in '
          'game_catalog.itemTypes');
    }
    if (rarity != null && !Rarity.values.any((r) => r.jsonName == rarity)) {
      errors.add('invalid rarity "$rarity" — use Common | Rare | Unique');
    }
    if (power != null && !(power > 0)) {
      errors.add('power must be > 0, got $power');
    }
    if (equipmentSlot != null) {
      final slot = EquipmentSlotEnum.values
          .where((s) => s.jsonName == equipmentSlot)
          .firstOrNull;
      if (slot == null) {
        errors.add('invalid equipmentSlot "$equipmentSlot" — valid slots '
            'are in game_catalog.equipmentSlots');
      } else if (hasCatalog) {
        final fits = switch (slot) {
          EquipmentSlotEnum.meleeGear =>
            ItemDatabase.meleeWeapons.contains(type),
          EquipmentSlotEnum.armorGear => ItemDatabase.armor.contains(type),
          EquipmentSlotEnum.rangedGear =>
            ItemDatabase.rangedWeapons.contains(type),
          _ => ItemDatabase.artifacts.contains(type),
        };
        if (!fits) {
          errors.add('"$type" cannot be equipped in $equipmentSlot');
        }
      }
    }
    void checkEnchant(Map<String, dynamic> e, String where) {
      final id = e['id'] as String? ?? '';
      final level = e['level'];
      if (EnchantmentDatabase.allEnchantments.isNotEmpty &&
          id != Constants.defaultEnchantmentId &&
          !EnchantmentDatabase.allEnchantments.contains(id)) {
        errors.add('unknown enchantment "$id" in $where — valid ids are '
            'in game_catalog.enchantments');
      }
      if (level is num &&
          (level < Constants.minimumEnchantmentTier ||
              level > Constants.maximumEnchantmentTier)) {
        errors.add('enchantment "$id" level $level out of range '
            '(${Constants.minimumEnchantmentTier}–${Constants.maximumEnchantmentTier})');
      }
    }

    enchantments?.forEach((e) => checkEnchant(e, 'enchantments'));
    if (netheriteEnchant != null) {
      checkEnchant(netheriteEnchant, 'netheriteEnchant');
    }
    if (armorProperties != null && ItemDatabase.armorProperties.isNotEmpty) {
      for (final p in armorProperties) {
        if (!ItemDatabase.armorProperties.contains(p['id'])) {
          errors.add('unknown armor property "${p['id']}" — valid ids '
              'are in game_catalog.armorProperties');
        }
      }
    }
    return errors;
  }

  void _throwIfErrors(List<String> errors) {
    if (errors.isNotEmpty) throw ArgumentError(errors.join('; '));
  }

  Map<String, dynamic> addItem({
    required String type,
    String location = 'inventory',
    String? equipmentSlot,
    double power = 1,
    String rarity = 'Common',
    bool markedNew = true,
    bool? upgraded,
    bool? gifted,
    List<Map<String, dynamic>>? enchantments,
    Map<String, dynamic>? netheriteEnchant,
    List<Map<String, dynamic>>? armorProperties,
  }) {
    final items = _listFor(location);
    if (items.length >= Constants.maximumInventoryItemCount) {
      throw StateError('item list is full '
          '(${Constants.maximumInventoryItemCount} max)');
    }
    _throwIfErrors(_itemErrors(
        type: type,
        equipmentSlot: equipmentSlot,
        rarity: rarity,
        power: power,
        enchantments: enchantments,
        netheriteEnchant: netheriteEnchant,
        armorProperties: armorProperties));
    final nextIndex = items.isEmpty
        ? 0
        : items
                .map((i) => i.inventoryIndex ?? 0)
                .reduce((a, b) => a > b ? a : b) +
            1;
    final item = Item.fromFields(
      type: type,
      power: power,
      rarity: Rarity.fromJsonName(rarity),
      markedNew: markedNew,
      upgraded: upgraded,
      gifted: gifted,
      inventoryIndex: nextIndex,
      equipmentSlot: equipmentSlot,
      enchantments: enchantments?.map((e) => Enchantment(e)).toList(),
      netheriteEnchant:
          netheriteEnchant != null ? Enchantment(netheriteEnchant) : null,
      armorProperties:
          armorProperties?.map((p) => ArmorProperty(p)).toList(),
    );
    // Upstream addEquippedItem: adding to a gear slot evicts the previous
    // item holding that slot.
    if (item.isGearItem()) {
      items.removeWhere((i) => i.equipmentSlot == equipmentSlot);
    }
    items.add(item);
    _commit(location, items);
    _changed();
    return {'index': items.length - 1, ...item.json};
  }

  Map<String, dynamic> updateItem(
      int index, String location, Map<String, dynamic> fields) {
    final item = _itemAt(index, location);
    const allowed = {
      'type',
      'power',
      'rarity',
      'markedNew',
      'upgraded',
      'gifted',
      'equipmentSlot',
      'investedPoints',
      'netheriteEnchant',
      'enchantments',
      'armorproperties',
      'timesmodified',
      'modified',
      'cloned',
      'inventoryIndex',
    };
    for (final key in fields.keys) {
      if (!allowed.contains(key)) {
        throw ArgumentError('Unsupported item field: $key');
      }
    }
    List<Map<String, dynamic>>? mapList(String key) =>
        (fields[key] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    _throwIfErrors(_itemErrors(
      type: (fields['type'] as String?) ?? item.type,
      equipmentSlot: fields.containsKey('equipmentSlot')
          ? fields['equipmentSlot'] as String?
          : item.equipmentSlot,
      rarity: (fields['rarity'] as String?) ?? item.rarity.jsonName,
      power: (fields['power'] as num?)?.toDouble(),
      enchantments: mapList('enchantments'),
      netheriteEnchant: fields.containsKey('netheriteEnchant')
          ? Map<String, dynamic>.from(fields['netheriteEnchant'] as Map)
          : null,
      armorProperties: mapList('armorproperties'),
    ));
    item.json.addAll(fields);
    _changed();
    return item.json;
  }

  Map<String, dynamic> duplicateItem(int index, String location) {
    final items = _listFor(location);
    if (items.length >= Constants.maximumInventoryItemCount) {
      throw StateError('item list is full '
          '(${Constants.maximumInventoryItemCount} max)');
    }
    final item = _itemAt(index, location);
    final copy = item.copy();
    copy.inventoryIndex = items.isEmpty
        ? 0
        : items.map((i) => i.inventoryIndex ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    items.add(copy);
    _commit(location, items);
    _changed();
    return {'index': items.length - 1, ...copy.json};
  }

  Map<String, dynamic> moveItem(int index, String location) {
    final from = _listFor(location);
    final to = _listFor(location == 'inventory' ? 'chest' : 'inventory');
    final item = _itemAt(index, location);
    from.remove(item);
    item.equipmentSlot = null;
    to.add(item);
    _commit(location, from);
    _commit(location == 'inventory' ? 'chest' : 'inventory', to);
    _changed();
    final movedTo = location == 'inventory' ? 'chest' : 'inventory';
    return {'movedTo': movedTo, 'index': to.length - 1, ...item.json};
  }

  void removeItem(int index, String location) {
    final items = _listFor(location);
    items.remove(_itemAt(index, location));
    _commit(location, items);
    _changed();
  }

  Item _itemAt(int index, String location) {
    final items = _listFor(location);
    if (index < 0 || index >= items.length) {
      throw ArgumentError('index $index out of range (0..${items.length - 1})');
    }
    return items[index];
  }

  Map<String, dynamic> setCurrency(String type, int count) {
    _requireOpen();
    final currencies = profile!.currency ??= <Currency>[];
    for (final c in currencies) {
      if (c.type.toLowerCase() == type.toLowerCase()) {
        c.count = count;
        _changed();
        return c.json;
      }
    }
    final created = Currency.fromFields(count: count, type: type);
    currencies.add(created);
    profile!.currency = currencies;
    _changed();
    return created.json;
  }

  Map<String, dynamic> setLevel(int level) {
    _requireOpen();
    if (level < Constants.minimumCharacterLevel ||
        level > Constants.maximumCharacterLevel) {
      throw ArgumentError(
          'level must be ${Constants.minimumCharacterLevel}–${Constants.maximumCharacterLevel}');
    }
    profile!.xp = GameCalculator.experienceForLevel(level);
    _changed();
    return {'level': GameCalculator.levelForExperience(profile!.xp), 'xp': profile!.xp};
  }

  Map<String, dynamic> setXp(int xp) {
    _requireOpen();
    profile!.xp = xp;
    _changed();
    return {'level': GameCalculator.levelForExperience(xp), 'xp': xp};
  }

  Future<Map<String, dynamic>> save([String? path]) async {
    _requireOpen();
    final target = path ?? filePath;
    if (target == null) {
      throw StateError('No path given and no file is open.');
    }
    profile!.totalGearPower = profile!.computeCharacterPower();
    final jsonBytes = ProfileParser.write(profile!);
    if (target.endsWith(Constants.decryptedFileExtension)) {
      await File(target).writeAsBytes(jsonBytes);
    } else {
      final processed = await FileProcessHelper.encrypt(jsonBytes);
      if (processed == null) {
        throw StateError('Failed to encrypt save data.');
      }
      await File(target).writeAsBytes(processed);
    }
    filePath = target;
    _changed();
    return {'written': target, 'bytes': File(target).lengthSync()};
  }

  /// Complete editing reference — every valid id, enum value, limit, and
  /// save-format rule an agent needs. Populated when the server runs inside
  /// the app (game content loaded from paks); empty lists otherwise.
  Map<String, dynamic> catalog() {
    List<String> sorted(Set<String> s) => s.toList()..sort();
    return {
      'gameContentLoaded': ItemDatabase.all.isNotEmpty,
      'itemTypes': {
        'melee': sorted(ItemDatabase.meleeWeapons),
        'ranged': sorted(ItemDatabase.rangedWeapons),
        'armor': sorted(ItemDatabase.armor),
        'artifacts': sorted(ItemDatabase.artifacts),
      },
      'enchantments': [
        for (final id in sorted(EnchantmentDatabase.allEnchantments))
          {
            'id': id,
            'name': R.enchantmentName(id),
            'powerful': Constants.powerful.contains(id),
          },
      ],
      'armorProperties': [
        for (final id in sorted(ItemDatabase.armorProperties))
          {'id': id, 'name': R.armorProperty(id)},
      ],
      'equipmentSlots': {
        for (final s in EquipmentSlotEnum.values) s.jsonName: s.name,
      },
      'rarities': [for (final r in Rarity.values) r.jsonName],
      'limits': {
        'maxInventoryItems': Constants.maximumInventoryItemCount,
        'characterLevel': {
          'min': Constants.minimumCharacterLevel,
          'max': Constants.maximumCharacterLevel,
        },
        'itemLevel': {
          'min': Constants.minimumItemLevel,
          'max': Constants.maximumItemLevel,
        },
        'enchantmentTier': {
          'min': Constants.minimumEnchantmentTier,
          'max': Constants.maximumEnchantmentTier,
        },
        'maxEnchantmentOptionsPerItem':
            Constants.maximumEnchantmentOptionsPerItem,
      },
      'saveFormat': {
        'itemFields': {
          'type': 'game item id, e.g. Sword, Battlestaff, FishingRod',
          'power': 'item power (double) — level = (power-1)*10+1',
          'rarity': 'Common | Rare | Unique',
          'equipmentSlot':
              'gear: MeleeGear | ArmorGear | RangedGear — artifacts: HotbarSlot1-3 — omit for plain inventory',
          'inventoryIndex': 'grid slot index for unequipped items',
          'enchantments':
              'list of {id, level, investedPoints}; each slot needs the full option list the game rolled, or an empty [] for no enchants',
          'netheriteEnchant':
              'optional gilded enchant {id, level} shown above the regular slots',
          'armorproperties':
              'armor only, list of {id, rarity} ids from armorProperties',
          'markedNew': 'yellow "new" corner badge',
          'upgraded': 'gilded-plus upgrade flag',
          'gifted': 'gift icon flag',
        },
        'rules': [
          'Adding an item with a gear equipmentSlot evicts the item currently holding that slot.',
          'Enchant ids "Unset" means an empty enchant slot.',
          'inventoryIndex must be unique within its list; the server assigns the next free index automatically.',
          'Changes are in-memory until save is called; .dat saves encrypted, .json decrypted.',
        ],
      },
    };
  }

  /// Full decrypted profile JSON — for agents that want everything at once.
  String dumpJson() {
    _requireOpen();
    return const JsonEncoder.withIndent('  ').convert(profile!.json);
  }
}

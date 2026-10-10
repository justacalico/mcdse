import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/constants.dart';
import '../data/enums.dart';
import '../pak/locres_reader.dart';
import '../pak/pak_index.dart';
import '../pak/pak_package.dart';
import 'content_resolver.dart';
import 'databases.dart';
import 'event_logger.dart';
import 'local_content_resolver.dart';

/// Ported from `PakContentResolver.cs` — discovers game content (icons,
/// armor properties, enchantments, localizations) inside the pak index and
/// extracts textures/strings on demand.
class PakContentResolver extends IImageResolver implements ILanguageResolver {
  PakContentResolver(this.pakIndex, this.path);

  static const Map<String, String> _mismatches = {
    // "Imagefile foldername" -> "Savefile reference"
    'TrickBow': 'Trickbow',
    'TrickBow_Unique1': 'Trickbow_Unique1',
    'TrickBow_Unique2': 'Trickbow_Unique2',
    'TrickBow_Year1': 'Trickbow_Year1',
    'LongBow': 'Longbow',
    'LongBow_Unique1': 'Longbow_Unique1',
    'LongBow_Unique2': 'Longbow_Unique2',
    'PowerBow': 'Powerbow',
    'PowerBow_Unique1': 'Powerbow_Unique1',
    'PowerBow_Unique2': 'Powerbow_Unique2',
    'Slowbow_Unique1': 'SlowBow_Unique1',
    'ShortBow': 'Shortbow',
    'ShortBow_Unique1': 'Shortbow_Unique1',
    'ShortBow_Unique2': 'Shortbow_Unique2',
    'ShortBow_Unique3': 'Shortbow_Unique3',
    'Huntingbow_Unique1': 'HuntingBow_Unique1',
    'TwistingVineBow_UNique1': 'TwistingVineBow_Unique1',
    'Battlerobe_unique1': 'BattleRobe_Unique1',
    'Sword_Steel': 'Sword',
    'Pickaxe_Steel': 'Pickaxe',
    'Pickaxe_Unique1_Steel': 'Pickaxe_Unique1',
    'Daggers_unique2': 'Daggers_Unique2',
    'Beenest': 'BeeNest',
    'SatchelofNourishment': 'SatchelOfNourishment',
    'SatchelofNeed': 'SatchelOfNeed',
    'Firetrail': 'FireTrail',
  };

  /// Items hidden from all lists because they won't work in game.
  static const List<String> _blockedItems = [
    'MysteryBox',
    'Potions',
    'Food',
    'Elytra',
    'EyeOfEnder',
    'Arrow_Icon',
    'TNTBox',
    'Trident',
    'HighlanderLongSword',
  ];

  final PakIndex pakIndex;
  @override
  final String? path;

  final LocalContentResolver _backupResolver = LocalContentResolver();

  final Map<String, String> _enchantments = {};
  final Map<String, String> _equipment = {};
  final Map<String, Uint8List?> _bitmaps = {};
  final Map<String, String> _localizations = {};
  final List<String> _levels = [];

  @override
  List<String> get localizationOptions => _localizations.keys.toList();

  List<String> get levels => List.unmodifiable(_levels);

  /// Walk the file index once, cataloguing everything we care about.
  /// Equivalent to upstream `loadPakFiles`.
  void loadPakFiles({bool preloadBitmaps = false}) {
    debugPrint('Loading Pak Files');
    for (final item in pakIndex.filePaths) {
      final startIndex = item.indexOf('//') + 1;
      final fullPath = item.substring(startIndex);

      if (fullPath.contains('Localization') && fullPath.endsWith('Game')) {
        final dir = _dirName(fullPath);
        final lang = dir.split('/').last;
        if (lang != 'Game') {
          _localizations[lang] = fullPath;
        }
        continue;
      }

      if (fullPath.contains('ArmorProperties') && !fullPath.contains('Cues')) {
        final dir = _dirName(fullPath);
        final armorProperty = dir.split('/').last;
        if (armorProperty == 'ArmorProperties' ||
            armorProperty == 'ReviveChance') {
          continue;
        }
        ItemDatabase.armorProperties.add(armorProperty);
        continue;
      }

      final filename = fullPath.split('/').last;
      final fullPathLowercase = fullPath.toLowerCase();

      if (fullPath.contains('data') && fullPath.contains('levels')) {
        _levels.add(filename);
        continue;
      }

      if (!filename.startsWith('T') || !fullPathLowercase.contains('_icon')) {
        continue;
      }

      if (preloadBitmaps) {
        final bitmap = extractBitmap(fullPath);
        if (bitmap != null) {
          _bitmaps[fullPath] = bitmap;
        }
      }

      final foldername = _dirName(fullPath).split('/').last;
      if (fullPath.contains('Enchantments') &&
          fullPathLowercase.endsWith('_icon')) {
        final enchantmentName = foldername;
        if (enchantmentName.endsWith('Shine')) continue;
        if (!_enchantments.containsKey(enchantmentName)) {
          _enchantments[enchantmentName] = fullPath;
          if (_mismatches.containsKey(enchantmentName)) {
            final corrected = _mismatches[enchantmentName]!;
            _enchantments[corrected] = fullPath;
            EnchantmentDatabase.allEnchantments.add(corrected);
          } else {
            EnchantmentDatabase.allEnchantments.add(enchantmentName);
          }
        }
        continue;
      }

      if (fullPathLowercase.endsWith('_icon_inventory')) {
        final itemName = foldername;
        if (!_equipment.containsKey(itemName)) {
          _equipment[itemName] = fullPath;
          if (_isItemValid(fullPath)) {
            ItemDatabase.all.add(itemName);
          }

          if (fullPath.contains('Equipment') && _isItemValid(fullPath)) {
            String? correctedItemName;
            if (_mismatches.containsKey(itemName)) {
              correctedItemName = _mismatches[itemName]!;
              _equipment[correctedItemName] = fullPath;
            }
            if (fullPath.contains('MeleeWeapons')) {
              ItemDatabase.meleeWeapons.add(correctedItemName ?? itemName);
            }
            if (fullPath.contains('RangedWeapons')) {
              ItemDatabase.rangedWeapons.add(correctedItemName ?? itemName);
            }
            if (fullPath.contains('Armor')) {
              ItemDatabase.armor.add(correctedItemName ?? itemName);
            }
          }

          if (fullPath.contains('Items') && _isItemValid(fullPath)) {
            String? correctedItemName;
            if (_mismatches.containsKey(itemName)) {
              correctedItemName = _mismatches[itemName]!;
              _equipment[correctedItemName] = fullPath;
            }
            ItemDatabase.artifacts.add(correctedItemName ?? itemName);
          }
        }
      }
    }

    debugPrint('Found ${_localizations.length} localizations');
    debugPrint('Found ${_levels.length} levels');
    debugPrint('Found ${ItemDatabase.armorProperties.length} armor properties');
    debugPrint('Found ${_equipment.length} equipment images');
    debugPrint('Found ${_enchantments.length} enchantment images');
    if (preloadBitmaps) {
      debugPrint('Preloaded ${_bitmaps.length} bitmaps');
    }
  }

  static String _dirName(String path) {
    final idx = path.lastIndexOf('/');
    return idx < 0 ? '' : path.substring(0, idx);
  }

  bool _isItemValid(String fullPath) =>
      !_blockedItems.any((blocked) => fullPath.contains(blocked));

  @override
  Map<String, Map<String, String>>? loadLanguageStrings(String langSpecifier) {
    final fullPath = _localizations[langSpecifier];
    if (fullPath == null) return null;

    final defaultStringLibrary = extractLocResFile(
        _localizations[Constants.defaultLangSpecifier] ?? '');
    if (langSpecifier == Constants.defaultLangSpecifier) {
      return defaultStringLibrary;
    }

    final stringLibrary = extractLocResFile(fullPath);
    if (stringLibrary != null && defaultStringLibrary != null) {
      var totalStringCount = 0;
      for (final pair in stringLibrary.entries.toList()) {
        totalStringCount += pair.value.length;
        final defaultValue = defaultStringLibrary[pair.key];
        if (defaultValue != null) {
          final merged = Map<String, String>.from(pair.value);
          defaultValue.forEach((k, v) => merged.putIfAbsent(k, () => v));
          stringLibrary[pair.key] = merged;
        }
      }
      debugPrint('Loaded $totalStringCount strings from $langSpecifier LocRes');
    }
    return stringLibrary;
  }

  /// Extracts a .locres file's entries.
  Map<String, Map<String, String>>? extractLocResFile(String fullPath) {
    final bytes = pakIndex.tryGetFile(fullPath);
    if (bytes == null) {
      EventLogger.logError('Could not get anything from $fullPath');
      return null;
    }
    try {
      return LocResReader(bytes).entries;
    } catch (e) {
      EventLogger.logError('Could not parse locres $fullPath: $e');
      return null;
    }
  }

  /// Decodes a texture package and returns PNG-encoded bytes.
  Uint8List? extractBitmap(String fullPath) {
    try {
      final pkg = pakIndex.tryGetPackage(fullPath);
      if (pkg == null) {
        EventLogger.logError('Could not get package from $fullPath');
        return null;
      }
      return _decodePackageTexture(pkg);
    } catch (e) {
      EventLogger.logError('Could not get package from $fullPath');
      return null;
    }
  }

  Uint8List? _decodePackageTexture(PakPackage package) {
    try {
      final texture = package.getTexture2D();
      if (texture == null) {
        EventLogger.logError('Could not get texture from package');
        return null;
      }
      final rgba = texture.decodeRgba();
      if (rgba == null) return null;
      final mip = texture.platformDatas[0].mips[0];
      final image = img.Image.fromBytes(
          width: mip.sizeX, height: mip.sizeY, bytes: rgba.buffer);
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      EventLogger.logError('Could not decode texture: $e');
      return null;
    }
  }

  @override
  Uint8List? imageSource(String pathWithoutExtension) {
    return _bitmaps.putIfAbsent(
        pathWithoutExtension, () => extractBitmap(pathWithoutExtension));
  }

  @override
  Uint8List? imageSourceForItemType(String itemType) {
    final fullPath = _equipment[itemType];
    if (fullPath != null) {
      final image = imageSource(fullPath);
      if (image != null) return image;
    }
    EventLogger.logError('Could not find full path for item $itemType');
    return _backupResolver.imageSourceForItemType(itemType);
  }

  @override
  Uint8List? imageSourceForRarity(Rarity rarity) {
    switch (rarity) {
      case Rarity.common:
        return imageSource(
            '/Dungeons/Content/UI/Materials/MissionSelectMap/inspector/loot/drops_gear_frame');
      case Rarity.rare:
        return imageSource(
            '/Dungeons/Content/UI/Materials/MissionSelectMap/inspector/loot/drops_rare_frame');
      case Rarity.unique:
        return imageSource(
            '/Dungeons/Content/UI/Materials/MissionSelectMap/inspector/loot/drops_unique_frame');
    }
  }

  @override
  Uint8List? imageSourceForEnchantmentId(String enchantmentId) {
    if (enchantmentId == Constants.defaultEnchantmentId) {
      return imageSource(
          '/Dungeons/Content/UI/Materials/MissionSelectMap/marker/locked_node');
    }
    final fullPath = _enchantments[enchantmentId];
    if (fullPath != null) {
      final image = imageSource(fullPath);
      if (image != null) return image;
    }
    EventLogger.logError('Could not find full path for enchantment $enchantmentId');
    return _backupResolver.imageSourceForEnchantmentId(enchantmentId);
  }
}

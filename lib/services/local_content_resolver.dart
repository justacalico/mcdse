import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../data/enums.dart';
import 'content_resolver.dart';
import 'databases.dart';
import 'event_logger.dart';

/// Ported from `LocalContentResolver.cs` — serves the small set of bundled
/// placeholder images when no game content is available.
class LocalContentResolver extends IImageResolver implements ILanguageResolver {
  LocalContentResolver({this.assetPrefix = 'assets/images'});

  final String assetPrefix;

  @override
  String? get path => null;

  @override
  List<String> get localizationOptions => const [];

  @override
  Map<String, Map<String, String>>? loadLanguageStrings(String langSpecifier) =>
      null;

  final Map<String, Uint8List?> _bundleCache = {};

  /// Preloads the bundled placeholder images. Call once during startup.
  Future<void> preload() async {
    for (final name in const [
      'MeleeWeapons.png',
      'RangedWeapons.png',
      'Armor.png',
      'Artifacts.png',
      'Enchantments.png',
      'Unknown.png',
    ]) {
      try {
        _bundleCache[name] =
            (await rootBundle.load('$assetPrefix/$name')).buffer.asUint8List();
      } catch (_) {
        EventLogger.logError('Error loading bundled image $name');
        _bundleCache[name] = null;
      }
    }
  }

  Uint8List? _assetBytes(String filename) => _bundleCache[filename];

  @override
  Uint8List? imageSource(String path) => null;

  String _folderNameForItemType(String type) {
    if (ItemDatabase.artifacts.contains(type)) return 'Artifacts';
    if (ItemDatabase.armor.contains(type)) return 'Armor';
    if (ItemDatabase.meleeWeapons.contains(type)) return 'MeleeWeapons';
    if (ItemDatabase.rangedWeapons.contains(type)) return 'RangedWeapons';
    return 'Unknown';
  }

  @override
  Uint8List? imageSourceForItemType(String itemType) {
    final folder = _folderNameForItemType(itemType);
    return _assetBytes('$folder.png');
  }

  @override
  Uint8List? imageSourceForRarity(Rarity rarity) => null;

  @override
  Uint8List? imageSourceForEnchantmentId(String enchantmentId) {
    if (enchantmentId == 'Unset') return null;
    return _assetBytes('Enchantments.png');
  }
}

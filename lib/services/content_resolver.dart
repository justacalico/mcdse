import 'dart:typed_data';

import '../data/enums.dart';
import '../data/models/enchantment.dart';
import '../data/models/item.dart';

/// Images are delivered as PNG-encoded bytes ready for `Image.memory` —
/// the portable equivalent of upstream's WPF `BitmapImage`.
abstract class IImageResolver {
  /// Path of the pak folder this resolver reads from, if any.
  String? get path;

  /// PNG bytes for the asset at [pathWithoutExtension] in the pak index.
  Uint8List? imageSource(String pathWithoutExtension);

  Uint8List? imageSourceForItem(Item item) => imageSourceForItemType(item.type);
  Uint8List? imageSourceForItemType(String itemType);
  Uint8List? imageSourceForRarity(Rarity rarity);
  Uint8List? imageSourceForEnchantment(Enchantment enchantment) =>
      imageSourceForEnchantmentId(enchantment.id);
  Uint8List? imageSourceForEnchantmentId(String enchantmentId);
}

abstract class ILanguageResolver {
  List<String> get localizationOptions;
  Map<String, Map<String, String>>? loadLanguageStrings(String langSpecifier);
}

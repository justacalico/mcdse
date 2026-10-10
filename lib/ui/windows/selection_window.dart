import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_model.dart';
import '../../data/constants.dart';
import '../../data/enums.dart';
import '../../services/config.dart';
import '../../services/databases.dart';
import '../../services/string_library.dart';
import '../widgets/item_control.dart';

/// Ported from `UI/Windows/SelectionWindow.xaml(.cs)` +
/// `BaseSelectionWindow.cs` — a search box over a filtered list used for
/// picking items, enchantments, and armor properties.
///
/// Returns the selected id via `Navigator.pop`.
class SelectionWindow extends StatefulWidget {
  SelectionWindow._({
    super.key,
    required this.title,
    required this.items,
    this.showFilterButtons = false,
    this.filter,
  });

  final String title;
  final List<SelectionEntry> items;

  /// Whether to show the MysteryBox filter buttons row (item pickers only).
  final bool showFilterButtons;

  /// Items for the all-items picker (with filter buttons).
  static Future<String?> showItems(BuildContext context, String? currentItemType) {
    final title = R.getString('merchant_slot_select_item') ?? R.selectItem;
    return show(
      context,
      title,
      ItemFilterEnum.all,
      showFilterButtons: true,
    );
  }

  /// Items filtered by [filter] (melee/ranged/armor/artifact).
  static Future<String?> showFilteredItems(
      BuildContext context, ItemFilterEnum filter, String? currentItemType) {
    return show(context, _titleForFilter(filter), filter);
  }

  static String _titleForFilter(ItemFilterEnum filter) {
    switch (filter) {
      case ItemFilterEnum.armor:
        return R.getString('merchant_slot_select_item') ?? R.selectArmor;
      case ItemFilterEnum.artifacts:
        return R.getString('merchant_slot_select_item') ?? R.selectArtifact;
      case ItemFilterEnum.meleeWeapons:
        return R.getString('merchant_slot_select_item') ?? R.selectMeleeWeapon;
      case ItemFilterEnum.rangedWeapons:
        return R.getString('merchant_slot_select_item') ?? R.selectRangedWeapon;
      default:
        return R.getString('merchant_slot_select_item') ?? R.selectItem;
    }
  }

  static Future<String?> showEnchantments(
      BuildContext context, String? currentId) {
    final title = R.getString('UIHints_SelectEnchantmentTitle') ??
        R.selectEnchantment;
    final entries = <SelectionEntry>[];
    for (final enchantment
        in [...EnchantmentDatabase.allEnchantments.toList()..sort(),
            Constants.defaultEnchantmentId]) {
      final image =
          ImageResolver.instance.imageSourceForEnchantmentId(enchantment);
      if (image == null) continue;
      entries.add(SelectionEntry(
        id: enchantment,
        filterableText: R.enchantmentName(enchantment),
        image: image,
        powerful: Constants.powerful.contains(enchantment),
      ));
    }
    return _showDialog(
        context, title, SelectionWindow._(title: title, items: entries));
  }

  static Future<String?> showArmorProperties(
      BuildContext context, String? currentId) {
    final bullet = ImageResolver.instance
        .imageSource('/Dungeons/Content/UI/Materials/Inventory2/Inspector/regular_bullit');
    final entries = ItemDatabase.armorProperties.toList()..sort();
    return _showDialog(
        context,
        R.selectArmorProperty,
        SelectionWindow._(
          title: R.selectArmorProperty,
          items: [
            for (final id in entries)
              SelectionEntry(
                  id: id,
                  filterableText: R.armorProperty(id),
                  image: bullet),
          ],
        ));
  }

  static Future<String?> show(BuildContext context, String title,
      ItemFilterEnum filter, {bool showFilterButtons = false}) {
    return _showDialog(
        context,
        title,
        SelectionWindow._(
            title: title,
            items: const [],
            showFilterButtons: showFilterButtons,
            filter: filter));
  }

  static Future<String?> _showDialog(
      BuildContext context, String title, Widget child) {
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(width: 300, height: 600, child: child),
      ),
    );
  }

  /// Initial item filter for the item picker (upstream `buildItemList`).
  final ItemFilterEnum? filter;

  @override
  State<SelectionWindow> createState() => _SelectionWindowState();
}

class SelectionEntry {
  SelectionEntry({
    required this.id,
    required this.filterableText,
    this.image,
    this.powerful = false,
  });

  final String id;
  final String filterableText;
  final Uint8List? image;
  final bool powerful;
}

class _SelectionWindowState extends State<SelectionWindow> {
  String _searchText = '';
  ItemFilterEnum _filter = ItemFilterEnum.all;

  @override
  void initState() {
    super.initState();
    if (widget.filter != null) _filter = widget.filter!;
  }

  /// Rebuilds the item list for the current filter (upstream `buildItemList`).
  List<SelectionEntry> get _items {
    if (widget.items.isNotEmpty) return widget.items;
    final ids = switch (_filter) {
      ItemFilterEnum.artifacts => ItemDatabase.artifacts,
      ItemFilterEnum.armor => ItemDatabase.armor,
      ItemFilterEnum.meleeWeapons => ItemDatabase.meleeWeapons,
      ItemFilterEnum.rangedWeapons => ItemDatabase.rangedWeapons,
      _ => ItemDatabase.all,
    }
        .toList()
      ..sort();
    return [
      for (final item in ids)
        if (ImageResolver.instance.imageSourceForItemType(item) != null)
          SelectionEntry(
            id: item,
            filterableText: R.itemName(item),
            image: ImageResolver.instance.imageSourceForItemType(item),
          ),
    ];
  }

  List<SelectionEntry> get _filteredItems {
    final items = _items;
    if (_searchText.trim().isEmpty) return items;
    final upper = _searchText.trim().toUpperCase();
    bool matchFirst(SelectionEntry i) =>
        i.filterableText.toUpperCase().startsWith(upper);
    bool matchSecond(SelectionEntry i) => i.id.toUpperCase().startsWith(upper);
    bool containsFirst(SelectionEntry i) =>
        i.filterableText.toUpperCase().contains(upper);
    bool containsSecond(SelectionEntry i) =>
        i.id.toUpperCase().contains(upper);
    return [
      ...items.where(matchFirst),
      ...items.where((i) => !matchFirst(i) && matchSecond(i)),
      ...items.where(
          (i) => !matchFirst(i) && !matchSecond(i) && containsFirst(i)),
      ...items.where((i) =>
          !matchFirst(i) &&
          !matchSecond(i) &&
          !containsFirst(i) &&
          containsSecond(i)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
                isDense: true, border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _searchText = v),
          ),
        ),
        if (widget.showFilterButtons)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final f in [
                ItemFilterEnum.all,
                ItemFilterEnum.meleeWeapons,
                ItemFilterEnum.rangedWeapons,
                ItemFilterEnum.armor,
                ItemFilterEnum.artifacts,
              ])
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: InkWell(
                    onTap: () => setState(() => _filter = f),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: ItemControl.memoryImage(
                          ImageResolver.instance.imageSourceForItemType(
                              _mysteryBoxForFilter(f))),
                    ),
                  ),
                ),
            ],
          ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final entry = items[index];
              final isUnique =
                  entry.id.toLowerCase().contains('unique');
              final uniqueBg = isUnique
                  ? ImageResolver.instance.imageSourceForRarity(Rarity.unique)
                  : null;
              return Container(
                decoration: uniqueBg == null
                    ? null
                    : BoxDecoration(
                        image: DecorationImage(
                            image: MemoryImage(uniqueBg), fit: BoxFit.cover)),
                child: ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 50,
                    height: 50,
                    child: ItemControl.memoryImage(entry.image),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                          child: Text(entry.filterableText,
                              style: const TextStyle(fontSize: 14))),
                      if (entry.powerful)
                        SizedBox(
                          width: 25,
                          height: 25,
                          child: ItemControl.memoryImage(
                              ImageResolver.instance.imageSource(
                                  '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/Inspector/element_powerful')),
                        ),
                    ],
                  ),
                  subtitle: Config.instance.showIDsInSelectionWindow
                      ? Text(entry.id, style: const TextStyle(fontSize: 10))
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _mysteryBoxForFilter(ItemFilterEnum filter) {
  switch (filter) {
    case ItemFilterEnum.all:
      return 'MysteryBoxAny';
    case ItemFilterEnum.armor:
      return 'MysteryBoxArmor';
    case ItemFilterEnum.artifacts:
      return 'MysteryBoxArtifact';
    case ItemFilterEnum.meleeWeapons:
      return 'MysteryBoxMelee';
    case ItemFilterEnum.rangedWeapons:
      return 'MysteryBoxRanged';
    case ItemFilterEnum.enchanted:
      return 'MysteryBoxAny';
  }
}

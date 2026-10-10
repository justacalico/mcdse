import 'package:flutter/material.dart';

import '../../app_model.dart';
import '../../data/constants.dart';
import '../../data/enums.dart';
import '../../data/models/item.dart';
import '../../services/event_logger.dart';
import '../../services/string_library.dart';
import '../../viewmodels/item_list_view_model.dart';
import '../property_widgets.dart';
import '../widgets/item_control.dart';
import '../windows/selection_window.dart';

/// Ported from `Screens/ItemListScreen.xaml(.cs)` — filter buttons, item grid,
/// count label, and the "+" add-item tile.
class ItemListScreen extends StatelessWidget {
  const ItemListScreen({super.key, required this.model});

  final ItemListViewModel model;

  static const int itemsPerRow = 3;
  static const double itemSide = 100;

  void _setFilter(ItemFilterEnum filter, String event) {
    if (model.profile.value == null) return;
    EventLogger.logEvent(event);
    model.filter.setValue = filter;
  }

  void _addNewItem(BuildContext context) {
    final currentFilter = model.filter.value;
    if (currentFilter == ItemFilterEnum.enchanted) return;
    EventLogger.logEvent('addNewItemButton_Click',
        {'currentFilter': currentFilter.toString()});
    if (AppModel.gameContentLoaded) {
      final picker = currentFilter == ItemFilterEnum.all
          ? SelectionWindow.showItems(context, null)
          : SelectionWindow.showFilteredItems(context, currentFilter, null);
      picker.then((picked) {
        if (picked == null || picked.isEmpty) return;
        final item = currentFilter == ItemFilterEnum.all
            ? Item.fromFields(
                markedNew: true,
                upgraded: false,
                power: 1,
                rarity: Rarity.common,
                type: picked)
            : Constants.createDefaultItemForFilter(currentFilter)
          ..type = picked;
        model.addItemToList(item);
        model.selectItem(item);
      });
      return;
    }
    if (currentFilter == ItemFilterEnum.all) return;
    final item = Constants.createDefaultItemForFilter(currentFilter);
    model.addItemToList(item);
    model.selectItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return PropertyBuilder(
      properties: [model.filteredItemList, model.filter, model.profile],
      builder: (context) {
        final items = model.profile.value == null
            ? null
            : model.filteredItemList.value;
        final currentFilter = model.filter.value;

        return SizedBox(
          width: 350,
          child: Column(
            children: [
              // Filter row.
              SizedBox(
                height: 35,
                child: Row(
                  children: [
                    _filterButton(ItemFilterEnum.all,
                        R.getString('ItemTag_All') ?? R.allItemsFilter,
                        '/Dungeons/Content/UI/Materials/Inventory2/Filter/filter_all_default',
                        'allItemsButton_Click'),
                    _filterButton(ItemFilterEnum.meleeWeapons,
                        R.getString('ItemTag_Melee') ?? R.meleeItemsFilter,
                        '/Dungeons/Content/UI/Materials/Inventory2/Filter/filter_melee_default',
                        'allMeleeItemsButton_Click',
                        enabled: AppModel.gameContentLoaded),
                    _filterButton(ItemFilterEnum.rangedWeapons,
                        R.getString('ItemTag_Ranged') ?? R.rangedItemsFilter,
                        '/Dungeons/Content/UI/Materials/Inventory2/Filter/filter_ranged_default',
                        'allRangedItemsButton_Click',
                        enabled: AppModel.gameContentLoaded),
                    _filterButton(ItemFilterEnum.armor,
                        R.getString('ItemTag_Armor') ?? R.armorItemsFilter,
                        '/Dungeons/Content/UI/Materials/Inventory2/Filter/filter_armour_default',
                        'allArmorItemsButton_Click',
                        enabled: AppModel.gameContentLoaded),
                    _filterButton(ItemFilterEnum.artifacts,
                        R.getString('ItemTag_Items') ?? R.artifactItemsFilter,
                        '/Dungeons/Content/UI/Materials/Inventory2/Filter/filter_consume_default',
                        'allArtifactItemsButton_Click',
                        enabled: AppModel.gameContentLoaded),
                    _filterButton(ItemFilterEnum.enchanted,
                        R.getString('ItemTag_Enchanted') ?? R.enchantedItemsFilter,
                        '/Dungeons/Content/UI/Materials/Inventory2/Filter/filter_enchant_default',
                        'allEnchantedItemsButton_Click'),
                  ],
                ),
              ),
              // Item grid.
              Expanded(
                child: items == null
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: _buildGrid(context, items, currentFilter),
                      ),
              ),
              // Count label.
              SizedBox(
                height: 35,
                child: Center(
                  child: Text(_countLabel(items?.length ?? 0)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterButton(ItemFilterEnum filter, String label, String imagePath,
      String event,
      {bool enabled = true}) {
    final isSelected = model.filter.value == filter;
    final icon =
        AppModel.gameContentLoaded ? ImageResolver.instance.imageSource(imagePath) : null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor:
                isSelected ? Colors.black.withValues(alpha: 0.08) : null,
          ),
          onPressed: enabled ? () => _setFilter(filter, event) : null,
          child: icon != null
              ? Image.memory(icon, fit: BoxFit.contain)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: const TextStyle(fontSize: 11),
                      softWrap: false,
                      textAlign: TextAlign.center),
                ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<Item> items, ItemFilterEnum currentFilter) {
    final children = <Widget>[
      for (final item in items)
        SizedBox(
          width: itemSide,
          height: itemSide,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => model.selectItem(item),
              child: ItemControl(item: item),
            ),
          ),
        ),
    ];

    // "+" tile appears for every filter except Enchanted (a new item has
    // no enchantments, so it would be filtered out immediately).
    if (currentFilter != ItemFilterEnum.enchanted &&
        model.profile.value != null) {
      children.add(SizedBox(
        width: itemSide,
        height: itemSide,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _addNewItem(context),
            child: const Center(
                child: Text('+', style: TextStyle(fontSize: 28))),
          ),
        ),
      ));
    }

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: children,
    );
  }

  String _countLabel(int itemCount) {
    if (model.profile.value == null) return '';
    var s = R.getString('inventory_count');
    if (s != null) {
      return s
          .replaceAll('{current}', itemCount.toString())
          .replaceAll('{max}', '${Constants.maximumInventoryItemCount}');
    }
    return R.formatItemsCountLabel(
        itemCount, Constants.maximumInventoryItemCount);
  }
}

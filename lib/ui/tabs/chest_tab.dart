import 'package:flutter/material.dart';

import '../../app_model.dart';
import '../../data/enums.dart';
import '../../data/models/item.dart';
import '../../viewmodels/profile_view_model.dart';
import '../property_widgets.dart';
import '../screens/enchantment_screen.dart';
import '../screens/item_list_screen.dart';
import '../screens/item_screen.dart';

/// Ported from `Tabs/ChestTab.xaml(.cs)` — storage chest item list + editor
/// with the enchantment overlay.
class ChestTab extends StatefulWidget {
  const ChestTab({super.key, required this.model});

  final ProfileViewModel model;

  @override
  State<ChestTab> createState() => ChestTabState();
}

class ChestTabState extends State<ChestTab> {
  ProfileViewModel get _model => widget.model;
  get _equipmentModel => _model.storageChestEquipmentModel;

  void deleteCurrentSelectedItem() {
    final item = _equipmentModel.selectedItem.value;
    if (item != null) removeItem(item);
  }

  void _duplicateItem(Item item) {
    _equipmentModel.selectEnchantment(null);
    _equipmentModel.addItemToList(item);
    _equipmentModel.selectItem(item);
  }

  void removeItem(Item item) {
    _equipmentModel.selectEnchantment(null);
    _equipmentModel.selectItem(null);
    _equipmentModel.removeItem(item);
  }

  void _moveItemToInventory(Item item) {
    final main = _model.mainEquipmentModel;
    main.selectEnchantment(null);
    main.addItemToList(item);
    main.selectItem(item);
    removeItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return PropertyBuilder(
      properties: [
        _model.profile,
        _equipmentModel.selectedItem,
        _equipmentModel.selectedEnchantment,
        _equipmentModel.remainingEnchantmentPoints,
      ],
      builder: (context) {
        final selectedEnchantment = _equipmentModel.selectedEnchantment.value;
        final selectedItem = _equipmentModel.selectedItem.value;

        return Column(
          children: [
            // Enchantment-points bar.
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ImageResolver.instance
                                .imageSource(
                                    '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/enchantscore_background') !=
                            null
                        ? Image.memory(
                            ImageResolver.instance.imageSource(
                                '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/enchantscore_background')!,
                            height: 22)
                        : Image.asset('assets/images/Points.png', height: 22),
                  ),
                  Text(
                    '${_equipmentModel.remainingEnchantmentPoints.value ?? ''}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 710,
                    child: Stack(
                      children: [
                        ItemListScreen(model: _equipmentModel),
                        if (selectedEnchantment != null) ...[
                          Positioned.fill(
                            child:
                                Container(color: Colors.black.withOpacity(0.5)),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: EnchantmentScreen(
                                enchantment: selectedEnchantment,
                                isGilded: _equipmentModel.selectedItem.value
                                        ?.netheriteEnchant !=
                                    null,
                                onClose: (_) =>
                                    _equipmentModel.selectEnchantment(null),
                                onSave: (e) =>
                                    _equipmentModel.saveEnchantment(e),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: ItemScreen(
                      itemLocation: ItemLocationEnum.chest,
                      item: selectedItem,
                      selectEnchantment: _equipmentModel.selectEnchantment,
                      saveChanges: _equipmentModel.saveItem,
                      duplicateItem: _duplicateItem,
                      deleteItem: removeItem,
                      moveItemToInventory: _moveItemToInventory,
                      addEnchantmentSlot: _equipmentModel.addEnchantmentSlot,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

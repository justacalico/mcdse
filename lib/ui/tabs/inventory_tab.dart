import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_model.dart';
import '../../data/enums.dart';
import '../../data/models/item.dart';
import '../../services/event_logger.dart';
import '../../viewmodels/profile_view_model.dart';
import '../property_widgets.dart';
import '../screens/enchantment_screen.dart';
import '../screens/equipment_screen.dart';
import '../screens/item_list_screen.dart';
import '../screens/item_screen.dart';

/// Ported from `Tabs/InventoryTab.xaml(.cs)` — currency row, equipment +
/// item list, item editor, enchantment overlay.
class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key, required this.model});

  final ProfileViewModel model;

  @override
  State<InventoryTab> createState() => InventoryTabState();
}

class InventoryTabState extends State<InventoryTab> {
  ProfileViewModel get _model => widget.model;
  get _equipmentModel => _model.mainEquipmentModel;

  final _emeraldsController = TextEditingController();
  final _goldController = TextEditingController();
  final _eyeOfEnderController = TextEditingController();
  final _currencyInvalid = <String, bool>{};

  @override
  void dispose() {
    _emeraldsController.dispose();
    _goldController.dispose();
    _eyeOfEnderController.dispose();
    super.dispose();
  }

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

  void _moveItemToStorage(Item item) {
    final chest = _model.storageChestEquipmentModel;
    chest.selectEnchantment(null);
    chest.addItemToList(item);
    chest.selectItem(item);
    removeItem(item);
  }

  Widget _currencyField(String name, String pakImagePath, String assetName,
      TextEditingController controller, void Function(int) setter) {
    final icon = AppModel.gameContentLoaded
        ? ImageResolver.instance.imageSource(pakImagePath)
        : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: icon != null
              ? Image.memory(icon, height: 22)
              : Image.asset('assets/images/$assetName', height: 22),
        ),
        SizedBox(
          width: 100,
          height: 22,
          child: TextField(
            controller: controller,
            enabled: _model.profile.value != null,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: _currencyInvalid[name] == true
                          ? Colors.red
                          : Colors.grey)),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (text) {
              final v = int.tryParse(text);
              if (v != null) {
                EventLogger.logEvent('${name}TextBox_TextChanged');
                setState(() => _currencyInvalid[name] = false);
                setter(v);
              } else {
                setState(() => _currencyInvalid[name] = true);
              }
            },
          ),
        ),
      ],
    );
  }

  void _syncCurrency() {
    final emeralds = _model.emeralds.value;
    if (_emeraldsController.text != (emeralds?.toString() ?? '')) {
      _emeraldsController.text = emeralds?.toString() ?? '';
    }
    final gold = _model.gold.value;
    if (_goldController.text != (gold?.toString() ?? '')) {
      _goldController.text = gold?.toString() ?? '';
    }
    final eoe = _model.eyeOfEnder.value;
    if (_eyeOfEnderController.text != (eoe?.toString() ?? '')) {
      _eyeOfEnderController.text = eoe?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PropertyBuilder(
      properties: [
        _model.profile,
        _model.emeralds,
        _model.gold,
        _model.eyeOfEnder,
        _model.unlockPortal,
        _equipmentModel.selectedItem,
        _equipmentModel.selectedEnchantment,
        _equipmentModel.remainingEnchantmentPoints,
      ],
      builder: (context) {
        _syncCurrency();
        final hasProfile = _model.profile.value != null;
        final unlockPortalValue = _model.unlockPortal.value;
        final showUnlockPortal =
            hasProfile && unlockPortalValue == false;
        final selectedEnchantment = _equipmentModel.selectedEnchantment.value;
        final selectedItem = _equipmentModel.selectedItem.value;

        return Stack(
          children: [
            Column(
              children: [
                // Currency bar.
                SizedBox(
                  height: 30,
                  child: Row(
                    children: [
                      _currencyField(
                          'emeralds',
                          '/Dungeons/Content/UI/Materials/Character/STATS_emerald',
                          'Emerald.png',
                          _emeraldsController,
                          (v) => _model.emeralds.setValue = v),
                      _currencyField(
                          'gold',
                          '/Dungeons/Content/UI/Materials/Currency/GoldIndicator',
                          'Gold.png',
                          _goldController,
                          (v) => _model.gold.setValue = v),
                      _currencyField(
                          'eyeOfEnder',
                          '/Dungeons/Content/UI/Materials/Currency/T_EyeOfEnder_Currency',
                          'EyeOfEnder.png',
                          _eyeOfEnderController,
                          (v) => _model.eyeOfEnder.setValue = v),
                      if (showUnlockPortal)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Tooltip(
                            message:
                                'Unlocking the ability to insert eyes of ender in stronghold',
                            child: TextButton(
                              onPressed: hasProfile
                                  ? () =>
                                      _model.unlockPortal.setValue = true
                                  : null,
                              child: const Text('Unlock Portal'),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ImageResolver.instance
                                    .imageSource(
                                        '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/enchantscore_background') !=
                                null
                            ? Image.memory(
                                ImageResolver.instance.imageSource(
                                    '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/enchantscore_background')!,
                                height: 22)
                            : Image.asset('assets/images/Points.png',
                                height: 22),
                      ),
                      Text(
                        '${_equipmentModel.remainingEnchantmentPoints.value ?? ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Body: equipment + list | item editor.
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 710,
                        child: Stack(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EquipmentScreen(
                                    model: _equipmentModel),
                                ItemListScreen(model: _equipmentModel),
                              ],
                            ),
                            if (selectedEnchantment != null) ...[
                              Positioned.fill(
                                child: Container(
                                    color: Colors.black
                                        .withValues(alpha: 0.5)),
                              ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(30),
                                  child: EnchantmentScreen(
                                    enchantment: selectedEnchantment,
                                    isGilded: _equipmentModel
                                            .selectedItem
                                            .value
                                            ?.netheriteEnchant !=
                                        null,
                                    onClose: (_) => _equipmentModel
                                        .selectEnchantment(null),
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
                          itemLocation: ItemLocationEnum.inventory,
                          item: selectedItem,
                          selectEnchantment:
                              _equipmentModel.selectEnchantment,
                          saveChanges: _equipmentModel.saveItem,
                          duplicateItem: _duplicateItem,
                          deleteItem: removeItem,
                          moveItemToChest: _moveItemToStorage,
                          addEnchantmentSlot:
                              _equipmentModel.addEnchantmentSlot,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

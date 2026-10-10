import 'package:flutter/material.dart';

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
  bool _syncing = false;

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
      TextEditingController controller, void Function(int) setter,
      int? currentValue) {
    final icon = AppModel.gameContentLoaded
        ? ImageResolver.instance.imageSource(pakImagePath)
        : null;
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Fixed slot so every icon lines up regardless of aspect ratio.
          SizedBox(
            width: 38,
            height: 30,
            child: Center(
              child: SizedBox(
                height: 20,
                child: icon != null
                    ? Image.memory(icon, fit: BoxFit.contain)
                    : Image.asset('assets/images/$assetName',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink()),
              ),
            ),
          ),
        if (currentValue == null)
          // Upstream `*AddButton` — creates the currency entry with 0.
          SizedBox(
            width: 100,
            height: 22,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: _model.profile.value != null
                  ? () => setter(0)
                  : null,
              child: const Center(
                  child: Text('+', style: TextStyle(fontSize: 13, height: 1))),
            ),
          )
        else
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
            onChanged: (text) {
              if (_syncing) return;
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
      ),
    );
  }

  void _syncCurrency() {
    // Guarded like upstream's IsEnabled check so programmatic syncs don't
    // rewrite the currency map via onChanged.
    _syncing = true;
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
    _syncing = false;
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _currencyField(
                          'emeralds',
                          '/Dungeons/Content/UI/Materials/Character/STATS_emerald',
                          'Emerald.png',
                          _emeraldsController,
                          (v) => _model.emeralds.setValue = v,
                          _model.emeralds.value),
                      _currencyField(
                          'gold',
                          '/Dungeons/Content/UI/Materials/Currency/GoldIndicator',
                          'Gold.png',
                          _goldController,
                          (v) => _model.gold.setValue = v,
                          _model.gold.value),
                      _currencyField(
                          'eyeOfEnder',
                          '/Dungeons/Content/UI/Materials/Currency/T_EyeOfEnder_Currency',
                          'EyeOfEnder.png',
                          _eyeOfEnderController,
                          (v) => _model.eyeOfEnder.setValue = v,
                          _model.eyeOfEnder.value),
                      if (showUnlockPortal)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Tooltip(
                            message:
                                'Unlocking the ability to insert eyes of ender in stronghold',
                            child: TextButton(
                              style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2)),
                              onPressed: hasProfile
                                  ? () =>
                                      _model.unlockPortal.setValue = true
                                  : null,
                              child: const Text('Unlock Portal',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          height: 20,
                          child: ImageResolver.instance
                                      .imageSource(
                                          '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/enchantscore_background') !=
                                  null
                              ? Image.memory(
                                  ImageResolver.instance.imageSource(
                                      '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/enchantscore_background')!,
                                  fit: BoxFit.contain)
                              : Image.asset('assets/images/Points.png',
                                  fit: BoxFit.contain),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${_equipmentModel.remainingEnchantmentPoints.value ?? ''}',
                          style: const TextStyle(fontSize: 14),
                        ),
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

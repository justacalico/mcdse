import 'package:flutter/material.dart';

import '../../app_model.dart';
import '../../data/constants.dart';
import '../../data/enums.dart';
import '../../data/models/item.dart';
import '../../services/event_logger.dart';
import '../../services/string_library.dart';
import '../../viewmodels/main_equipment_view_model.dart';
import '../property_widgets.dart';
import '../widgets/item_control.dart';
import '../widgets/stepper.dart';

/// Ported from `Screens/EquipmentScreen.xaml(.cs)` — level editor, character
/// power, and the six equipment slots.
class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key, required this.model});

  final MainEquipmentViewModel model;

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  late final TextEditingController _levelController;
  bool _syncing = false;

  MainEquipmentViewModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    _levelController = TextEditingController();
  }

  @override
  void dispose() {
    _levelController.dispose();
    super.dispose();
  }

  void _syncLevelText(int? level) {
    final text = level?.toString() ?? '';
    if (_levelController.text == text) return;
    // Guarded like upstream's IsEnabled check: a programmatic sync must
    // not fire onChanged (which would rewrite xp).
    _syncing = true;
    _levelController.text = text;
    _syncing = false;
  }

  Widget _slotButton(EquipmentSlotEnum slot, Item? Function() getItem) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Builder(builder: (context) {
        final item = getItem();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (item != null) {
                _model.selectItem(item);
              } else {
                _addNewEquippedItem(slot);
              }
            },
            child: item == null
                ? const Center(
                    child: Text('+', style: TextStyle(fontSize: 28)))
                : ItemControl(item: item),
          ),
        );
      }),
    );
  }

  void _addNewEquippedItem(EquipmentSlotEnum slot) {
    EventLogger.logEvent('addNewEquippedItemButton_Click',
        {'equipmentSlot': slot.toString()});
    final item = Constants.createDefaultItemForEquipmentSlot(slot);
    _model.addEquippedItem(item);
    _model.selectItem(item);
  }

  void _onLevelChanged(String text) {
    if (_syncing || !_model.equipmentCanExist.value) return;
    final level = int.tryParse(text);
    if (level != null) {
      EventLogger.logEvent('levelTextBox_TextChanged', {'level': level});
      _model.level.setValue = level;
    }
  }

  void _stepLevel(int delta) {
    if (!_model.equipmentCanExist.value) return;
    final level = int.tryParse(_levelController.text);
    if (level == null) return;
    final newLevel = level + delta;
    if (delta > 0 && newLevel > Constants.maximumCharacterLevel) return;
    if (delta < 0 && newLevel < Constants.minimumCharacterLevel) return;
    _model.level.setValue = newLevel;
  }

  @override
  Widget build(BuildContext context) {
    return PropertyBuilder(
      properties: [
        _model.level,
        _model.equippedItemList,
        _model.characterPower,
        _model.equipmentCanExist,
      ],
      builder: (context) {
        _syncLevelText(_model.level.value);
        final canExist = _model.equipmentCanExist.value;

        final levelFrame = ImageResolver.instance.imageSource(
            '/Dungeons/Content/UI/Materials/Character/STATS_LV_frame');
        final powerFrame = ImageResolver.instance.imageSource(
            '/Dungeons/Content/UI/Materials/Inventory2/Power/gearstrenght_icon');

        return SizedBox(
          width: 330,
          child: Column(
            children: [
              // Level + power row.
              SizedBox(
                height: 135,
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    Stack(
                      children: [
                        SizedBox(
                          width: 135,
                          height: 135,
                          child: ItemControl.memoryImage(levelFrame),
                        ),
                        Positioned.fill(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  R.getString('HUD_Level') ?? R.level,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 70,
                                height: 30,
                                child: TextField(
                                  controller: _levelController,
                                  enabled: canExist &&
                                      _model.level.value != null,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                      border: InputBorder.none, isDense: true),
                                  onChanged: _onLevelChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 52,
                          child: StepperControl(
                            width: 30,
                            height: 30,
                            onUp: () => _stepLevel(1),
                            onDown: () => _stepLevel(-1),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Power display.
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 40,
                            height: 40,
                            child: ItemControl.memoryImage(powerFrame)),
                        Text(R.getString('gearpower_POWER') ?? R.power,
                            style: const TextStyle(fontSize: 12)),
                        SizedBox(
                          width: 80,
                          height: 30,
                          child: Center(
                            child: Text(
                                '${_model.characterPower.value ?? ''}',
                                style: const TextStyle(fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 26),
                  ],
                ),
              ),
              // Gear row: melee, armor, ranged.
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    _slotButton(EquipmentSlotEnum.meleeGear,
                        _model.meleeGearItem),
                    const SizedBox(width: 5),
                    _slotButton(EquipmentSlotEnum.armorGear,
                        _model.armorGearItem),
                    const SizedBox(width: 5),
                    _slotButton(EquipmentSlotEnum.rangedGear,
                        _model.rangedGearItem),
                  ],
                ),
              ),
              const Spacer(),
              // Hotbar row: three artifact slots.
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    _slotButton(EquipmentSlotEnum.hotbarSlot1,
                        _model.hotbarSlot1Item),
                    const SizedBox(width: 5),
                    _slotButton(EquipmentSlotEnum.hotbarSlot2,
                        _model.hotbarSlot2Item),
                    const SizedBox(width: 5),
                    _slotButton(EquipmentSlotEnum.hotbarSlot3,
                        _model.hotbarSlot3Item),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

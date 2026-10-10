import 'package:flutter/material.dart';

import '../../app_model.dart';
import '../../data/constants.dart';
import '../../data/models/enchantment.dart';
import '../../data/models/item.dart';
import '../../services/event_logger.dart';
import '../../services/string_library.dart';
import '../windows/selection_window.dart';
import 'item_control.dart';
import 'stepper.dart';

/// Ported from `UserControls/NetheriteEnchantmentControl.xaml(.cs)` — the
/// gilded checkbox + the netherite enchantment editor row.
class NetheriteEnchantmentControl extends StatefulWidget {
  const NetheriteEnchantmentControl({super.key, this.item, this.saveChanges});

  final Item? item;

  /// Called when the underlying item/enchantment was edited.
  final void Function()? saveChanges;

  @override
  State<NetheriteEnchantmentControl> createState() =>
      _NetheriteEnchantmentControlState();
}

class _NetheriteEnchantmentControlState
    extends State<NetheriteEnchantmentControl> {
  late final TextEditingController _tierController;
  bool _invalid = false;

  Item? get _item => widget.item;
  Enchantment? get enchantment => _item?.netheriteEnchant;
  set enchantment(Enchantment? value) {
    if (_item != null) {
      _item!.netheriteEnchant = value;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _tierController =
        TextEditingController(text: enchantment?.level.toString() ?? '');
  }

  @override
  void didUpdateWidget(NetheriteEnchantmentControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _tierController.text = enchantment?.level.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _tierController.dispose();
    super.dispose();
  }

  void _onTierChanged(String text) {
    final ench = enchantment;
    if (ench == null) return;
    final level = int.tryParse(text);
    if (level != null && ench.level != level) {
      EventLogger.logEvent('netheriteEnchantmentTierTextBox_TextChanged');
      ench.level = level;
      setState(() => _invalid = false);
      widget.saveChanges?.call();
    } else if (level == null) {
      setState(() => _invalid = true);
    }
  }

  void _step(int delta) {
    final ench = enchantment;
    if (ench == null) return;
    final level = int.tryParse(_tierController.text);
    if (level == null) return;
    final newLevel = level + delta;
    if (delta > 0 && newLevel > Constants.maximumEnchantmentTier) return;
    if (delta < 0 && newLevel < Constants.minimumEnchantmentTier) return;
    _tierController.text = newLevel.toString();
    _onTierChanged(_tierController.text);
  }

  Future<void> _selectedEnchantmentId(String? enchantmentId) async {
    if (enchantmentId == null) {
      enchantment = null;
    } else {
      if (enchantment == null) {
        enchantment = Enchantment.fromFields(id: enchantmentId, level: 0);
      } else {
        enchantment!.id = enchantmentId;
      }
    }
    widget.saveChanges?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final ench = enchantment;
    return SizedBox(
      height: 27,
      child: Row(
        children: [
          // Gilded checkbox (enabled only when item has no netherite enchant).
          TextButton.icon(
            onPressed: item != null &&
                    item.netheriteEnchant == null &&
                    AppModel.gameContentLoaded
                ? () {
                    EventLogger.logEvent('gildedButton_Click');
                    _selectedEnchantmentId(Constants.defaultEnchantmentId);
                  }
                : null,
            icon: Icon(item?.netheriteEnchant != null
                ? Icons.check_box
                : Icons.check_box_outline_blank, size: 16),
            label: Text(R.getString('iteminspector_gilded') ?? R.gilded),
          ),
          if (item == null || ench == null) const Spacer(),
          if (item != null && ench != null) ...[
            // Enchantment icon button + tier editor + name.
            InkWell(
              onTap: AppModel.gameContentLoaded
                  ? () async {
                      final result = await SelectionWindow.showEnchantments(
                          context, enchantment?.id);
                      await _selectedEnchantmentId(result);
                    }
                  : null,
              child: SizedBox(
                width: 20,
                height: 20,
                child: ItemControl.memoryImage(
                    ImageResolver.instance.imageSourceForEnchantment(ench)),
              ),
            ),
            SizedBox(
              width: 30,
              child: TextField(
                controller: _tierController,
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: _invalid ? Colors.red : Colors.grey)),
                ),
                onChanged: _onTierChanged,
              ),
            ),
            StepperControl(
              width: 26,
              height: 27,
              onUp: () => _step(1),
              onDown: () => _step(-1),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Text(R.enchantmentName(ench.id),
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          if (item != null && ench != null)
            SizedBox(
              width: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: AppModel.gameContentLoaded
                    ? () {
                        EventLogger.logEvent(
                            'netheriteEnchantmentRemoveButton_Click');
                        _selectedEnchantmentId(null);
                      }
                    : null,
                icon: const Text('X'),
              ),
            ),
        ],
      ),
    );
  }
}

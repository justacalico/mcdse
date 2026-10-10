import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_model.dart';
import '../../data/constants.dart';
import '../../data/models/enchantment.dart';
import '../../logic/extensions.dart';
import '../../services/event_logger.dart';
import '../../services/string_library.dart';
import '../windows/selection_window.dart';
import '../widgets/item_control.dart';
import '../widgets/stepper.dart';

/// Ported from `Screens/EnchantmentScreen.xaml(.cs)` — the enchantment editor
/// overlay (icon, powerful badge, tier editor, point cost, close button).
class EnchantmentScreen extends StatefulWidget {
  const EnchantmentScreen({
    super.key,
    required this.enchantment,
    required this.isGilded,
    this.onClose,
    this.onSave,
  });

  final Enchantment? enchantment;
  final bool isGilded;

  /// Called with null when the user presses the close button.
  final void Function(Enchantment? enchantment)? onClose;

  /// Called after edits mutate the enchantment.
  final void Function(Enchantment enchantment)? onSave;

  @override
  State<EnchantmentScreen> createState() => _EnchantmentScreenState();
}

class _EnchantmentScreenState extends State<EnchantmentScreen> {
  late final TextEditingController _tierController;

  Enchantment? get _enchantment => widget.enchantment;

  @override
  void initState() {
    super.initState();
    _tierController = TextEditingController();
    _syncText();
  }

  @override
  void didUpdateWidget(EnchantmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enchantment != widget.enchantment) {
      _syncText();
    }
  }

  void _syncText() {
    _tierController.text = _enchantment?.level.toString() ?? '';
  }

  @override
  void dispose() {
    _tierController.dispose();
    super.dispose();
  }

  String _enchantmentLevelImagePath(int level) {
    final clamped = level.clamp(0, Constants.maximumEnchantmentTier);
    return '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/Inspector2/lv${clamped}_frame';
  }

  void _onTierChanged(String text) {
    final ench = _enchantment;
    if (ench == null) return;
    final level = int.tryParse(text);
    if (level != null && ench.level != level) {
      EventLogger.logEvent('tierTextBox_TextChanged', {'level': level});
      ench.level = level;
      widget.onSave?.call(ench);
      setState(() {});
    }
  }

  void _stepTier(int delta) {
    final ench = _enchantment;
    if (ench == null) return;
    final level = int.tryParse(_tierController.text);
    if (level == null) return;
    final newLevel = level + delta;
    if (delta > 0 && newLevel > Constants.maximumEnchantmentTier) return;
    if (delta < 0 && newLevel < Constants.minimumEnchantmentTier) return;
    _tierController.text = newLevel.toString();
    _onTierChanged(_tierController.text);
  }

  Future<void> _pickEnchantment() async {
    if (!AppModel.gameContentLoaded) return;
    EventLogger.logEvent('enchantmentImageButton_Click',
        {'enchantment': _enchantment?.id ?? 'null'});
    final selected =
        await SelectionWindow.showEnchantments(context, _enchantment?.id);
    if (selected == null) return;
    final ench = _enchantment;
    if (ench == null) {
      widget.onSave?.call(Enchantment.fromFields(id: selected, level: 0));
    } else {
      ench.id = selected;
      widget.onSave?.call(ench);
    }
    setState(() => _syncText());
  }

  @override
  Widget build(BuildContext context) {
    final ench = _enchantment;
    if (ench == null) return const SizedBox.shrink();

    final isPowerful = ench.isPowerful();
    final enchantmentImage =
        ImageResolver.instance.imageSourceForEnchantment(ench);

    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 198, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isPowerful)
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: ItemControl.memoryImage(
                                ImageResolver.instance.imageSource(
                                    '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/Inspector/element_powerful')),
                          ),
                        Text(
                          isPowerful
                              ? (R.getString('enchantment_rarity_powerful') ??
                                  R.powerful)
                              : (R.getString('enchantment_rarity_common') ??
                                  R.common),
                        ),
                      ],
                    ),
                    Text(R.enchantmentName(ench.id),
                        style: const TextStyle(fontSize: 24)),
                    Text(R.enchantmentDescription(ench.id),
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: SizedBox(
                  width: 178,
                  height: 178,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap:
                          AppModel.gameContentLoaded ? _pickEnchantment : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (AppModel.gameContentLoaded)
                            ItemControl.memoryImage(ImageResolver.instance
                                .imageSource(
                                    _enchantmentLevelImagePath(ench.level))),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: ItemControl.memoryImage(enchantmentImage),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: SizedBox(
                  width: 25,
                  height: 25,
                  child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () {
                      EventLogger.logEvent('closeButton_Click');
                      widget.onClose?.call(null);
                    },
                    child: const Text('X', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
          // Bottom: tier editor + point cost.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(R.getString('enchantment_upgrade_tiers') ?? R.tier),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 40,
                        height: 34,
                        child: TextField(
                          controller: _tierController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24),
                          decoration: const InputDecoration(
                              border: InputBorder.none, isDense: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: _onTierChanged,
                        ),
                      ),
                      StepperControl(
                        height: 34,
                        width: 26,
                        onUp: () => _stepTier(1),
                        onDown: () => _stepTier(-1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: ItemControl.memoryImage(
                            ImageResolver.instance.imageSource(
                                '/Dungeons/Content/UI/Materials/Inventory2/Enchantment/enchant_counter')),
                      ),
                      Text(
                        widget.isGilded
                            ? '${ench.gildedPointsCost()}'
                            : '${ench.pointsCost()}',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

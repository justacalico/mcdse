import 'package:flutter/material.dart';

import '../../app_model.dart';
import '../../data/constants.dart';
import '../../data/models/enchantment.dart';
import 'item_control.dart' show ItemControl;

/// Ported from `UserControls/EnchantmentSetControl.xaml(.cs)` — the diamond
/// arrangement of three enchantment slots plus the "upgraded" overlay.
class EnchantmentSetControl extends StatelessWidget {
  const EnchantmentSetControl({super.key, this.enchantments, this.command});

  /// Up to three enchantments for this set (slice of the item's list).
  final List<Enchantment>? enchantments;

  /// Called with the tapped enchantment (null = add slot).
  final void Function(Enchantment? enchantment)? command;

  @override
  Widget build(BuildContext context) {
    final enchantments = this.enchantments;
    final background = ImageResolver.instance.imageSource(
        '/Dungeons/Content/UI/Materials/StatusEffect/Enchantment/EnchantmentsBackground');
    final topSymbol = ImageResolver.instance.imageSource(
        '/Dungeons/Content/UI/Materials/Mobs/enchant_common_icon');

    Enchantment? upgraded;
    if (enchantments != null) {
      for (final e in enchantments) {
        if (e.level > 0) {
          upgraded = e;
          break;
        }
      }
    }
    // Upstream `clearAll` behavior: an empty set shows one big "Unset" slot
    // in the middle, which adds a new set when tapped.
    final showCenterUnset = enchantments == null || enchantments.isEmpty;

    Widget enchantButton(int index) {
      final ench = enchantments != null && enchantments.length > index
          ? enchantments[index]
          : null;
      final img = ench == null
          ? null
          : ImageResolver.instance.imageSourceForEnchantment(ench);
      return Transform.rotate(
        angle: 0.7853982, // 45° diamond, like the WPF layout
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => command?.call(ench),
            child: ench == null
                ? const SizedBox.expand()
                : Transform.rotate(
                    angle: -0.7853982,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ItemControl.memoryImage(img),
                    ),
                  ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (background != null) Image.memory(background, fit: BoxFit.contain),
          if (upgraded != null || showCenterUnset)
            // Single center button for the upgraded (or empty "Unset")
            // enchantment.
            Center(
              child: Transform.rotate(
                angle: 0.7853982,
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => command?.call(upgraded),
                      child: Transform.rotate(
                        angle: -0.7853982,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: ItemControl.memoryImage(
                              ImageResolver.instance.imageSourceForEnchantment(
                                  upgraded ??
                                      Enchantment.fromFields(
                                          id: Constants.defaultEnchantmentId))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            // Diamond arrangement: symbol top, slots left/bottom/right —
            // matching the WPF grid layout.
            LayoutBuilder(
              builder: (context, constraints) {
                final cell = constraints.biggest.shortestSide / 3;
                return Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: cell,
                        height: cell,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: ItemControl.memoryImage(topSymbol),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                          width: cell, height: cell, child: enchantButton(2)),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                          width: cell, height: cell, child: enchantButton(1)),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                          width: cell, height: cell, child: enchantButton(0)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_model.dart';
import '../../data/models/item.dart';
import '../../logic/extensions.dart';
import '../../services/config.dart';
import '../../services/string_library.dart';

/// Ported from `UserControls/ItemControl.xaml(.cs)` — the 100×100 inventory
/// item tile with rarity frame, gilded overlay, enchantment point count,
/// power and name.
class ItemControl extends StatelessWidget {
  const ItemControl({super.key, this.item});

  final Item? item;

  @override
  Widget build(BuildContext context) {
    final it = item;
    if (it == null) return const SizedBox.expand();

    final itemImage = ImageResolver.instance.imageSourceForItem(it);
    final title = R.itemName(it.type);
    final points = it.enchantmentPoints();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Rarity frame behind everything.
        memoryImage(ImageResolver.instance.imageSourceForRarity(it.rarity)),
        // Gilded plate overlay.
        if (it.netheriteEnchant != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 3, 4, 4),
            child: memoryImage(ImageResolver.instance.imageSource(
                '/Dungeons/Content/Content_DLC4/UI/Materials/Inventory/Inventory_slot_gilded_plate')),
          ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: memoryImage(itemImage),
        ),
        // "New" marker, top-right.
        if (it.markedNew == true)
          Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 32,
              height: 32,
              child: memoryImage(ImageResolver.instance.imageSource(
                  '/Dungeons/Content/UI/Materials/HotBar2/Icons/inventoryslot_newitem')),
            ),
          ),
        // Inventory index / equipment slot, top-right (Config toggle).
        if (Config.instance.showInventoryIndexOrEquipmentSlot)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text('${it.inventoryIndex ?? it.equipmentSlot}',
                  style: const TextStyle(fontSize: 10)),
            ),
          ),
        // Item name when no image is available.
        if (itemImage == null || !AppModel.gameContentLoaded)
          Align(
            alignment: Alignment.center,
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
        // Enchantment points chip, top-left.
        if (points > 0)
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 6, top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 12,
                      height: 13,
                      child: memoryImage(ImageResolver.instance.imageSource(
                          '/Dungeons/Content/UI/Materials/Mobs/enchant_common_icon'))),
                  Text('$points',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        // Power, bottom-right.
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 2),
            child: Text('${it.level()}',
                style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  static Widget memoryImage(Uint8List? bytes) {
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(bytes, fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink());
  }
}

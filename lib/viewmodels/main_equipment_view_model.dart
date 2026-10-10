import '../core/property.dart';
import '../data/enums.dart';
import '../data/models/item.dart';
import '../logic/extensions.dart';
import 'item_list_view_model.dart';

/// Ported from `ViewModels/MainEquipmentViewModel.cs`.
class MainEquipmentViewModel extends ItemListViewModel {
  MainEquipmentViewModel(super.profile);

  @override
  List<Item> get items => profile.value?.items ?? const [];

  @override
  set items(List<Item> value) {
    if (profile.value == null) return;
    profile.value!.items = value;
  }

  void addEquippedItem(Item item) {
    if (profile.value == null) return;
    var inventory = items;
    if (item.isGearItem()) {
      final toRemove = item.equipmentSlot;
      inventory = inventory.where((i) => i.equipmentSlot != toRemove).toList();
    }
    items = inventory.adding(item);

    triggerSubscribersForItem(item);
  }

  @override
  void triggerSubscribersForItem(Item item) {
    if (item.inventoryIndex != null) {
      (filteredItemList as MappedProperty).setValue =
          (filteredItemList as MappedProperty).value;
    }
    if (item.equipmentSlot != null) {
      (equippedItemList as MappedProperty).setValue =
          (equippedItemList as MappedProperty).value;
    }
    super.triggerSubscribersForItem(item);
  }

  Item? getGearItem(EquipmentSlotEnum slot) =>
      ItemListViewModel.equipmentSlotItem(equippedItemList.value, slot);

  Item? meleeGearItem() => getGearItem(EquipmentSlotEnum.meleeGear);
  Item? armorGearItem() => getGearItem(EquipmentSlotEnum.armorGear);
  Item? rangedGearItem() => getGearItem(EquipmentSlotEnum.rangedGear);
  Item? hotbarSlot1Item() => getGearItem(EquipmentSlotEnum.hotbarSlot1);
  Item? hotbarSlot2Item() => getGearItem(EquipmentSlotEnum.hotbarSlot2);
  Item? hotbarSlot3Item() => getGearItem(EquipmentSlotEnum.hotbarSlot3);
}

import '../core/property.dart';
import '../data/constants.dart';
import '../data/enums.dart';
import '../data/models/item.dart';
import '../data/models/profile_save_file.dart';
import '../logic/extensions.dart';
import '../logic/game_calculator.dart';
import 'equipment_view_model.dart';

/// Ported from `ViewModels/ItemListViewModel.cs`.
abstract class ItemListViewModel extends EquipmentViewModel {
  ItemListViewModel(super.profile){
    equipmentCanExist = profile.map((p) => p != null);
    level = profile.map<int?>(
        (p) => p?.level() ?? Constants.minimumCharacterLevel, setXpFromLevel);
    filteredItemList = _filter.map(getFilteredItems);
    equippedItemList = profile.map<List<Item>>(
        (p) => p?.items?.where((x) => x.equipmentSlot != null).toList() ?? const []);
    characterPower = equippedItemList.map(computeCharacterPower);

    profile.subscribe((p) {
      filter.setValue = ItemFilterEnum.all;
      selectedItemProperty.setValue = null;
    });
    level.subscribe((_) => updateEnchantmentPoints());
    equippedItemList.subscribe((_) => updateEnchantmentPoints());
    selectedItem.subscribe((_) => updateEnchantmentPoints());
  }

  static List<Item> applyFilterToItems(List<Item> items, ItemFilterEnum filter) {
    switch (filter) {
      case ItemFilterEnum.all:
        return items;
      case ItemFilterEnum.meleeWeapons:
        return items.where((x) => x.isMeleeWeapon()).toList();
      case ItemFilterEnum.rangedWeapons:
        return items.where((x) => x.isRangedWeapon()).toList();
      case ItemFilterEnum.armor:
        return items.where((x) => x.isArmor()).toList();
      case ItemFilterEnum.artifacts:
        return items.where((x) => x.isArtifact()).toList();
      case ItemFilterEnum.enchanted:
        return items.where((x) => x.enchantmentPoints() > 0).toList();
    }
  }

  static Item? equipmentSlotItem(
      Iterable<Item> itemList, EquipmentSlotEnum equipmentSlot) {
    final equipmentSlotString = equipmentSlot.jsonName;
    for (final item in itemList) {
      if (item.equipmentSlot == equipmentSlotString) return item;
    }
    return null;
  }

  static int? computeCharacterPower(Iterable<Item> items) {
    final melee = equipmentSlotItem(items, EquipmentSlotEnum.meleeGear)?.power ?? 0;
    final armor = equipmentSlotItem(items, EquipmentSlotEnum.armorGear)?.power ?? 0;
    final ranged =
        equipmentSlotItem(items, EquipmentSlotEnum.rangedGear)?.power ?? 0;
    final slot1 =
        equipmentSlotItem(items, EquipmentSlotEnum.hotbarSlot1)?.power ?? 0;
    final slot2 =
        equipmentSlotItem(items, EquipmentSlotEnum.hotbarSlot2)?.power ?? 0;
    final slot3 =
        equipmentSlotItem(items, EquipmentSlotEnum.hotbarSlot3)?.power ?? 0;
    final characterPower = GameCalculator.characterPowerFromEquippedItemPowers(
        melee, armor, ranged, slot1, slot2, slot3);
    return GameCalculator.levelFromPower(characterPower);
  }

  void setXpFromLevel(ProfileSaveFile? p, int? value) {
    if (p == null || value == null) return;
    p.xp = GameCalculator.experienceForLevel(value);
  }

  List<Item> get items;
  set items(List<Item> value);

  List<Item> getFilteredItems(ItemFilterEnum filter) {
    final inventory =
        items.where((x) => x.equipmentSlot == null).toList();
    return applyFilterToItems(inventory, filter)
      ..sort((a, b) =>
          (a.inventoryIndex ?? 0).compareTo(b.inventoryIndex ?? 0));
  }

  final Property<ItemFilterEnum> _filter = Property(ItemFilterEnum.all);
  IReadWriteProperty<ItemFilterEnum> get filter => _filter;

  late IReadProperty<List<Item>> filteredItemList;

  void addItemToList(Item item) {
    if (profile.value == null) return;
    items = addingItemToCollection(items, item);
    triggerSubscribersForItem(item);
  }

  void removeItem(Item item) {
    if (profile.value == null) return;
    items = items.removing(item);
    triggerSubscribersForItem(item);
  }

  @override
  void saveItem(Item item) {
    final selected = selectedItem.value;
    if (profile.value == null || selected == null) return;
    items = items.replacing(selected, item);
    triggerSubscribersForItem(item);
  }

  List<Item> addingItemToCollection(List<Item> collection, Item item) {
    final index = _getMaxIndex(collection) + 1;
    item.inventoryIndex = index;
    return [...collection, item];
  }

  int _getMaxIndex(List<Item> collection) {
    if (collection.isEmpty) return -1;
    var maxIndex = 0;
    for (final item in collection) {
      final idx = item.inventoryIndex ?? 0;
      if (idx > maxIndex) maxIndex = idx;
    }
    return maxIndex;
  }
}

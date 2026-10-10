import '../core/property.dart';
import '../data/models/item.dart';
import '../data/models/profile_save_file.dart';
import 'item_list_view_model.dart';

/// Ported from `ViewModels/StorageChestEquipmentViewModel.cs`.
class StorageChestEquipmentViewModel extends ItemListViewModel {
  StorageChestEquipmentViewModel(Property<ProfileSaveFile?> profile) : super(profile);

  @override
  List<Item> get items => profile.value?.storageChestItems ?? const [];

  @override
  set items(List<Item> value) {
    if (profile.value == null) return;
    profile.value!.storageChestItems = value;
  }

  @override
  void triggerSubscribersForItem(Item item) {
    if (item.inventoryIndex != null) {
      (filteredItemList as MappedProperty).setValue =
          (filteredItemList as MappedProperty).value;
    }
    super.triggerSubscribersForItem(item);
  }
}

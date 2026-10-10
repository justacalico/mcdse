import '../core/property.dart';
import '../data/constants.dart';
import '../data/models/enchantment.dart';
import '../data/models/item.dart';
import '../data/models/profile_save_file.dart';
import '../logic/extensions.dart';
import '../services/event_logger.dart';

/// Ported from `ViewModels/EquipmentViewModel.cs`.
abstract class EquipmentViewModel {
  EquipmentViewModel(Property<ProfileSaveFile?> profile) : _profile = profile {
    updateEnchantmentPoints();
  }

  final Property<ProfileSaveFile?> _profile;
  IReadProperty<ProfileSaveFile?> get profile => _profile;

  /// Upstream's `protected readonly Property<Item?> _selectedItem`.
  final Property<Item?> selectedItemProperty = Property<Item?>(null);
  IReadProperty<Item?> get selectedItem => selectedItemProperty;

  /// Upstream's `protected readonly Property<Enchantment?> _selectedEnchantment`.
  final Property<Enchantment?> selectedEnchantmentProperty =
      Property<Enchantment?>(null);
  IReadProperty<Enchantment?> get selectedEnchantment => selectedEnchantmentProperty;

  late IReadProperty<List<Item>> equippedItemList;
  late IReadWriteProperty<int?> level;
  late IReadProperty<int?> characterPower;
  late IReadProperty<bool> equipmentCanExist;

  final Property<int?> _remainingEnchantmentPoints = Property<int?>(null);
  IReadProperty<int?> get remainingEnchantmentPoints => _remainingEnchantmentPoints;

  void updateEnchantmentPoints() {
    _remainingEnchantmentPoints.setValue = profile.value?.remainingEnchantmentPoints();
  }

  void selectItem(Item? item) {
    EventLogger.logEvent('selectItem', {'item': item?.type ?? 'null'});
    selectedItemProperty.setValue = item;
  }

  void saveItem(Item item);

  void triggerSubscribersForItem(Item item) {
    selectedItemProperty.setValue = selectedItemProperty.value;
  }

  void selectEnchantment(Enchantment? enchantment) {
    EventLogger.logEvent(
        'selectEnchantment', {'enchantment': enchantment?.id ?? 'null'});
    selectedEnchantmentProperty.setValue = enchantment;
  }

  void saveEnchantment(Enchantment enchantment) {
    final profileValue = profile.value;
    final selItem = selectedItem.value;
    final selEnch = selectedEnchantment.value;
    if (profileValue == null || selItem == null || selEnch == null) return;
    final enchantments = selItem.enchantments?.toList() ?? [];
    final index = enchantments.indexOf(selEnch);
    if (index < 0) return;

    enchantments.removeAt(index);
    enchantments.insert(index, enchantment);
    selItem.enchantments = enchantments;

    saveItem(selItem);
  }

  void addEnchantmentSlot() {
    final selItem = selectedItem.value;
    if (profile.value == null || selItem == null) return;
    final enchantments = selItem.enchantments?.toList() ?? [];
    if (enchantments.length >= Constants.maximumEnchantmentOptionsPerItem) return;
    enchantments
        .add(Enchantment.fromFields(id: Constants.defaultEnchantmentId, level: 0));
    enchantments
        .add(Enchantment.fromFields(id: Constants.defaultEnchantmentId, level: 0));
    enchantments
        .add(Enchantment.fromFields(id: Constants.defaultEnchantmentId, level: 0));
    selItem.enchantments =
        enchantments.take(Constants.maximumEnchantmentOptionsPerItem).toList();

    saveItem(selItem);
  }
}

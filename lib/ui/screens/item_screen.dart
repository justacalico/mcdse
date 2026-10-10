import 'package:flutter/material.dart';

import '../../app_model.dart';
import '../../data/constants.dart';
import '../../data/enums.dart';
import '../../data/models/armor_property.dart';
import '../../data/models/enchantment.dart';
import '../../data/models/item.dart';
import '../../logic/extensions.dart';
import '../../logic/game_calculator.dart';
import '../../services/event_logger.dart';
import '../../services/string_library.dart';
import '../windows/selection_window.dart';
import '../widgets/enchantment_set_control.dart';
import '../widgets/item_control.dart';
import '../widgets/netherite_enchantment_control.dart';
import '../widgets/stepper.dart';

/// Ported from `Screens/ItemScreen.xaml(.cs)` — the right-hand item editor:
/// icon, power, rarity, flags, armor properties, gilded enchantment,
/// description and the three enchantment sets.
class ItemScreen extends StatefulWidget {
  const ItemScreen({
    super.key,
    required this.item,
    this.itemLocation,
    this.selectEnchantment,
    this.saveChanges,
    this.duplicateItem,
    this.deleteItem,
    this.moveItemToInventory,
    this.moveItemToChest,
    this.moveItemToTower,
    this.addEnchantmentSlot,
    this.onEnchantmentsChanged,
  });

  final Item? item;
  final ItemLocationEnum? itemLocation;

  final void Function(Enchantment? enchantment)? selectEnchantment;
  final void Function(Item item)? saveChanges;
  final void Function(Item item)? duplicateItem;
  final void Function(Item item)? deleteItem;
  final void Function(Item item)? moveItemToInventory;
  final void Function(Item item)? moveItemToChest;
  final void Function(Item item)? moveItemToTower;
  final void Function()? addEnchantmentSlot;

  /// Called after a local edit (so the tab can refresh the enchantment
  /// overlay without re-selecting).
  final VoidCallback? onEnchantmentsChanged;

  @override
  State<ItemScreen> createState() => ItemScreenState();
}

class ItemScreenState extends State<ItemScreen> {
  late final TextEditingController _powerController;
  bool _powerInvalid = false;
  bool _syncing = false;

  Item? get _item => widget.item;

  @override
  void initState() {
    super.initState();
    _powerController = TextEditingController();
    _syncPower();
  }

  @override
  void didUpdateWidget(ItemScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _syncPower();
      _powerInvalid = false;
    }
  }

  void _syncPower() {
    // Guarded like upstream's IsEnabled check so programmatic syncs don't
    // mutate item.power via onChanged.
    _syncing = true;
    _powerController.text = _item?.level().toString() ?? '';
    _syncing = false;
  }

  @override
  void dispose() {
    _powerController.dispose();
    super.dispose();
  }

  /// Re-renders the enchantment sets (upstream `updateEnchantmentsUI`).
  void updateEnchantmentsUI() => setState(() {});

  void _save() {
    if (_item != null) widget.saveChanges?.call(_item!);
    setState(() {});
  }

  // ---- power / rarity ----

  void _onPowerChanged(String text) {
    final item = _item;
    if (_syncing || item == null) return;
    final level = int.tryParse(text);
    if (level != null) {
      EventLogger.logEvent('powerTextBox_TextChanged', {'level': level});
      item.power = GameCalculator.powerFromLevel(level);
      setState(() => _powerInvalid = false);
      widget.saveChanges?.call(item);
    } else {
      setState(() => _powerInvalid = true);
    }
  }

  void _stepPower(int delta) {
    final item = _item;
    if (item == null) return;
    final level = int.tryParse(_powerController.text);
    if (level == null) return;
    final newLevel = level + delta;
    if (delta > 0 && newLevel > Constants.maximumItemLevel) return;
    if (delta < 0 && newLevel < Constants.minimumItemLevel) return;
    _powerController.text = newLevel.toString();
    _onPowerChanged(_powerController.text);
  }

  void _onRarityChanged(Rarity? rarity) {
    final item = _item;
    if (item == null || rarity == null) return;
    EventLogger.logEvent('rarityComboBox_SelectionChanged',
        {'rarity': rarity.toString()});
    item.rarity = rarity;
    _save();
  }

  // ---- flag checkboxes ----

  void _toggleMarkedNew() {
    final item = _item;
    if (item == null) return;
    item.markedNew = item.markedNew != true;
    EventLogger.logEvent('markedNewButton_Click',
        {'markedNew': item.markedNew.toString()});
    _save();
  }

  void _toggleUpgraded() {
    final item = _item;
    if (item == null) return;
    item.upgraded = !(item.upgraded ?? false);
    EventLogger.logEvent('upgradedButton_Click',
        {'upgraded': item.upgraded.toString()});
    _save();
  }

  void _toggleGifted() {
    final item = _item;
    if (item == null) return;
    item.gifted = item.gifted != true;
    EventLogger.logEvent('giftedButton_Click',
        {'gifted': item.gifted.toString()});
    _save();
  }

  // ---- item type picker ----

  Future<void> _pickItemType() async {
    final item = _item;
    if (item == null || !AppModel.gameContentLoaded) return;
    EventLogger.logEvent('inventoryItemButton_Click', {'item': item.type});
    final filter = _filterFor(item);
    final selected = filter == ItemFilterEnum.all
        ? await SelectionWindow.showItems(context, item.type)
        : await SelectionWindow.showFilteredItems(context, filter, item.type);
    if (selected == null) return;
    if (_item == null) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
              title: Text(R.error),
              content: Text(R.itemWasDeletedErrorMessage)),
        );
      }
      return;
    }
    _item!.type = selected;
    _save();
  }

  static ItemFilterEnum _filterFor(Item item) {
    if (item.isArmor()) return ItemFilterEnum.armor;
    if (item.isArtifact()) return ItemFilterEnum.artifacts;
    if (item.isMeleeWeapon()) return ItemFilterEnum.meleeWeapons;
    if (item.isRangedWeapon()) return ItemFilterEnum.rangedWeapons;
    return ItemFilterEnum.all;
  }

  // ---- armor properties ----

  void _addArmorProperty() {
    final item = _item;
    if (item == null || !item.isArmor()) return;
    EventLogger.logEvent('plusArmorPropertyButton_Click');
    final props = item.armorProperties?.toList() ?? <ArmorProperty>[];
    props.add(ArmorProperty.fromFields(
        id: Constants.defaultArmorPropertyId, rarity: Rarity.common));
    item.armorProperties = props;
    setState(() {});
  }

  void _removeArmorProperty(ArmorProperty armorProperty) {
    final item = _item;
    if (item == null) return;
    EventLogger.logEvent('armorPropertyRemoveButton_Click',
        {'armorProperty': armorProperty.id});
    final list = item.armorProperties?.toList() ?? [];
    list.remove(armorProperty);
    item.armorProperties = list;
    setState(() {});
  }

  Future<void> _replaceArmorProperty(ArmorProperty armorProperty) async {
    if (!AppModel.gameContentLoaded) return;
    EventLogger.logEvent('armorPropertyButton_Click',
        {'armorProperty': armorProperty.id});
    final newId =
        await SelectionWindow.showArmorProperties(context, armorProperty.id);
    if (newId == null) return;
    final props = _item?.armorProperties;
    if (props == null) return;
    final idx = props.indexWhere((p) => p.id == armorProperty.id);
    if (idx >= 0) {
      props[idx].id = newId;
      setState(() {});
    }
  }

  // ---- enchantments ----

  void _onEnchantmentTap(Enchantment? enchantment) {
    if (enchantment == null) {
      widget.addEnchantmentSlot?.call();
      setState(() {});
    } else {
      widget.selectEnchantment?.call(enchantment);
    }
  }

  Widget _itemImage(Item item) {
    final bytes = ImageResolver.instance.imageSourceForItem(item);
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    return Image.asset('assets/images/Armor.png',
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }

  Widget _flagCheckbox(String label, bool checked, VoidCallback onTap) {
    final hasItem = _item != null;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: TextButton.icon(
        onPressed: hasItem ? onTap : null,
        icon: Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final hasItem = item != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Power + rarity row.
                    Row(
                      children: [
                        SizedBox(
                          width: 114,
                          child: TextField(
                            controller: _powerController,
                            enabled: hasItem,
                            style: const TextStyle(fontSize: 20),
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: _powerInvalid
                                          ? Colors.red
                                          : Colors.grey)),
                            ),
                            onChanged: _onPowerChanged,
                          ),
                        ),
                        StepperControl(
                          width: 26,
                          height: 34,
                          onUp: hasItem ? () => _stepPower(1) : null,
                          onDown: hasItem ? () => _stepPower(-1) : null,
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<Rarity>(
                          value: item?.rarity,
                          onChanged: hasItem ? _onRarityChanged : null,
                          items: [
                            DropdownMenuItem(
                                value: Rarity.common,
                                child: Text(
                                    R.getString('rarity_common') ?? R.common)),
                            DropdownMenuItem(
                                value: Rarity.rare,
                                child: Text(
                                    R.getString('rarity_rare') ?? R.rare)),
                            DropdownMenuItem(
                                value: Rarity.unique,
                                child: Text(
                                    R.getString('rarity_unique') ?? R.unique)),
                          ],
                        ),
                      ],
                    ),
                    // Flag row.
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        children: [
                          _flagCheckbox(
                              R.getString('Interest_New') ?? R.new_,
                              item?.markedNew == true,
                              _toggleMarkedNew),
                          _flagCheckbox(
                              R.getString('item_diamond_dust_upgraded') ??
                                  R.upgraded,
                              item?.upgraded == true,
                              _toggleUpgraded),
                          _flagCheckbox(
                              R.getString('item_gifted') ?? R.gifted,
                              item?.gifted == true,
                              _toggleGifted),
                        ],
                      ),
                    ),
                    // Name.
                    Text(hasItem ? R.itemName(item.type) : '',
                        style: const TextStyle(fontSize: 24)),
                    // Armor properties.
                    if (hasItem && item.isArmor())
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final prop
                                  in item.armorProperties ?? const <ArmorProperty>[])
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: AppModel.gameContentLoaded
                                            ? () => _replaceArmorProperty(prop)
                                            : null,
                                        child: SizedBox(
                                          height: 32,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: ItemControl.memoryImage(
                                                    ImageResolver.instance
                                                        .imageSource(
                                                            '/Dungeons/Content/UI/Materials/Inventory2/Inspector/regular_bullit')),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  '${R.armorProperty(prop.id)}: ${R.armorPropertyDescription(prop.id)}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 20,
                                      height: 32,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        iconSize: 12,
                                        icon: const Text('X'),
                                        onPressed: () =>
                                            _removeArmorProperty(prop),
                                      ),
                                    ),
                                  ],
                                ),
                              SizedBox(
                                height: 32,
                                child: TextButton(
                                  onPressed: AppModel.gameContentLoaded
                                      ? _addArmorProperty
                                      : null,
                                  child: const Text('+',
                                      style: TextStyle(fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Netherite/gilded enchantment row.
                    if (hasItem && !item.isArtifact())
                      NetheriteEnchantmentControl(
                        item: item,
                        saveChanges: () {
                          if (_item != null) {
                            widget.saveChanges?.call(_item!);
                          }
                        },
                      ),
                    // Description.
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text(hasItem ? R.itemDesc(item.type) : '',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            // Item image button + action buttons.
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: hasItem && AppModel.gameContentLoaded
                            ? _pickItemType
                            : null,
                        child: item == null
                            ? const SizedBox.shrink()
                            : _itemImage(item),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 70,
                      height: 30,
                      child: TextButton(
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                        onPressed: hasItem
                            ? () {
                                EventLogger.logEvent(
                                    'duplicateItemButton_Click',
                                    {'item': item.type});
                                widget.duplicateItem?.call(item.copy());
                              }
                            : null,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(R.duplicate,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      height: 30,
                      child: TextButton(
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                        onPressed: hasItem
                            ? () {
                                EventLogger.logEvent('deleteItemButton_Click',
                                    {'item': item.type});
                                widget.deleteItem?.call(item);
                              }
                            : null,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              R.getString('Delete_Nav_Button') ?? R.delete,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                ..._moveButtons(item),
              ],
            ),
          ],
        ),
        const Spacer(),
        // Enchantment sets row (hidden for artifacts / no item).
        if (hasItem && !item.isArtifact())
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < 3; i++)
                    EnchantmentSetControl(
                      enchantments:
                          item.enchantments?.skip(i * 3).take(3).toList(),
                      command: _onEnchantmentTap,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _moveButtons(Item? item) {
    final loc = widget.itemLocation;
    if (item == null || loc == null) {
      return const [SizedBox.shrink()];
    }
    String label;
    VoidCallback? onPressed;
    String? extraLabel;
    VoidCallback? extraOnPressed;
    switch (loc) {
      case ItemLocationEnum.inventory:
        label = R.getString('transfer_to_storage') ?? R.moveToStorage;
        onPressed = () => widget.moveItemToChest?.call(item);
      case ItemLocationEnum.chest:
        label = R.getString('transfer_to_inventory') ?? R.moveToInventory;
        onPressed = () => widget.moveItemToInventory?.call(item);
      case ItemLocationEnum.tower:
        label = R.getString('transfer_to_inventory') ?? R.moveToInventory;
        onPressed = () => widget.moveItemToInventory?.call(item);
        extraLabel = R.getString('transfer_to_storage') ?? R.moveToStorage;
        extraOnPressed = () => widget.moveItemToChest?.call(item);
    }
    return [
      SizedBox(
        height: 27,
        width: 150,
        child: TextButton(onPressed: onPressed, child: Text(label)),
      ),
      if (extraLabel != null)
        SizedBox(
          height: 27,
          width: 150,
          child:
              TextButton(onPressed: extraOnPressed, child: Text(extraLabel)),
        ),
    ];
  }
}

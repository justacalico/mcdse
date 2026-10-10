import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/app_model.dart';
import 'package:mcdse/data/constants.dart';
import 'package:mcdse/data/enums.dart';
import 'package:mcdse/data/models/enchantment.dart';
import 'package:mcdse/data/models/item.dart';
import 'package:mcdse/services/string_library.dart';
import 'package:mcdse/ui/widgets/netherite_enchantment_control.dart';
import 'package:mcdse/ui/widgets/stat_field.dart';
import 'package:mcdse/ui/widgets/stepper.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  tearDown(() => AppModel.gameContentLoaded = false);

  group('StatField', () {
    testWidgets('renders value and commits valid edits', (tester) async {
      int? got;
      await tester.pumpWidget(_wrap(StatField(
          title: 'Level', value: 5, onChanged: (v) => got = v)));
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '42');
      await tester.pump();
      expect(got, 42);
    });

    testWidgets('rejects non-numeric input', (tester) async {
      int? got;
      await tester.pumpWidget(_wrap(StatField(
          title: 'XP', value: 1, onChanged: (v) => got = v)));
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(got, isNull);
    });

    testWidgets('stepper clamps to min/max', (tester) async {
      int? got;
      await tester.pumpWidget(_wrap(StatField(
          title: 'P', value: 0, minValue: 0, maxValue: 2,
          onChanged: (v) => got = v)));
      final stepper = find.byType(StepperControl);
      expect(stepper, findsOneWidget);
      await tester.tap(find.descendant(
          of: stepper, matching: find.byIcon(Icons.arrow_drop_up)));
      await tester.pump();
      expect(got, 1);
      await tester.tap(find.descendant(
          of: stepper, matching: find.byIcon(Icons.arrow_drop_up)));
      await tester.pump();
      expect(got, 2);
      await tester.tap(find.descendant(
          of: stepper, matching: find.byIcon(Icons.arrow_drop_up)));
      await tester.pump();
      expect(got, 2);
      await tester.tap(find.descendant(
          of: stepper, matching: find.byIcon(Icons.arrow_drop_down)));
      await tester.pump();
      expect(got, 1);
      await tester.tap(find.descendant(
          of: stepper, matching: find.byIcon(Icons.arrow_drop_down)));
      await tester.pump();
      await tester.tap(find.descendant(
          of: stepper, matching: find.byIcon(Icons.arrow_drop_down)));
      await tester.pump();
      expect(got, 0);
    });

    testWidgets('didUpdateWidget refreshes the text', (tester) async {
      await tester.pumpWidget(_wrap(
          const StatField(title: 'V', value: 1)));
      await tester.pumpWidget(_wrap(
          const StatField(title: 'V', value: 9)));
      expect(find.text('9'), findsOneWidget);
    });
  });

  group('NetheriteEnchantmentControl', () {
    testWidgets('gilded button creates enchantment; X removes it',
        (tester) async {
      AppModel.gameContentLoaded = true;
      var saved = 0;
      final item = Item.fromFields(type: 'Sword', power: 1);
      await tester.pumpWidget(_wrap(NetheriteEnchantmentControl(
          item: item, saveChanges: () => saved++)));
      await tester.pump();
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(item.netheriteEnchant, isNotNull);
      expect(item.netheriteEnchant!.id, Constants.defaultEnchantmentId);
      expect(saved, greaterThan(0));
      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();
      expect(item.netheriteEnchant!.level, 3);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(item.netheriteEnchant, isNull);
    });

    testWidgets('tier field rejects garbage and stepper respects bounds',
        (tester) async {
      AppModel.gameContentLoaded = true;
      final item = Item.fromFields(type: 'Sword', power: 1);
      item.netheriteEnchant =
          Enchantment.fromFields(id: 'Sharpness', level: 0);
      await tester.pumpWidget(_wrap(NetheriteEnchantmentControl(item: item)));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      expect(item.netheriteEnchant!.level, 0);
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      final stepper = find.byType(StepperControl);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.descendant(
            of: stepper, matching: find.byIcon(Icons.arrow_drop_up)));
        await tester.pump();
      }
      expect(item.netheriteEnchant!.level, Constants.maximumEnchantmentTier);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.descendant(
            of: stepper, matching: find.byIcon(Icons.arrow_drop_down)));
        await tester.pump();
      }
      expect(item.netheriteEnchant!.level, Constants.minimumEnchantmentTier);
    });

    testWidgets('renders nothing extra without an item', (tester) async {
      await tester
          .pumpWidget(_wrap(const NetheriteEnchantmentControl()));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('Constants defaults', () {
    test('default item id per equipment slot', () {
      expect(
          Constants.defaultItemIdForEquipmentSlot(
              EquipmentSlotEnum.meleeGear),
          Constants.defaultMeleeWeaponId);
      expect(
          Constants.defaultItemIdForEquipmentSlot(
              EquipmentSlotEnum.rangedGear),
          Constants.defaultRangedWeaponId);
      expect(
          Constants.defaultItemIdForEquipmentSlot(
              EquipmentSlotEnum.armorGear),
          Constants.defaultArmorId);
    });

    test('filter mapping and default item creation', () {
      for (final slot in EquipmentSlotEnum.values) {
        final filter = Constants.itemFilterForEquipmentSlot(slot);
        expect(filter, isA<ItemFilterEnum>());
      }
      for (final filter in [
        ItemFilterEnum.meleeWeapons,
        ItemFilterEnum.rangedWeapons,
        ItemFilterEnum.armor,
        ItemFilterEnum.artifacts,
      ]) {
        final item = Constants.createDefaultItemForFilter(filter);
        expect(item.type, isNotEmpty);
      }
      expect(() => Constants.createDefaultItemForFilter(ItemFilterEnum.all),
          throwsArgumentError);
      expect(
          () => Constants.createDefaultItemForFilter(
              ItemFilterEnum.enchanted),
          throwsArgumentError);
      for (final slot in EquipmentSlotEnum.values) {
        final item =
            Constants.createDefaultItemForEquipmentSlot(slot);
        expect(item.equipmentSlot, slot.jsonName);
      }
    });

    test('paths resolve under both envs', () {
      expect(Constants.launcherPaksFolderPath, contains('Paks'));
      expect(Constants.steamPaksFolderPath, contains('Paks'));
      expect(Constants.xboxPcGamesPaksFolderPath, contains('Paks'));
      expect(Constants.fileDialogInitialDirectory,
          contains('Dungeons'));
    });
  });

  group('R string lookups', () {
    test('falls back to raw ids when no strings loaded', () {
      expect(R.itemName('SomeItem'), 'SomeItem');
      expect(R.enchantmentName('SomeEnchant'), 'SomeEnchant');
      expect(R.getString('nonexistent_key'), isNull);
      expect(R.getMissionName('nonexistent_mission'), 'nonexistent_mission_name');
      expect(R.totalStringCount, greaterThanOrEqualTo(0));
    });
  });
}

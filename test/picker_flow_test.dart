import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/app_model.dart';
import 'package:mcdse/core/property.dart';
import 'package:mcdse/data/models/profile_save_file.dart';
import 'package:mcdse/services/content_resolver.dart';
import 'package:mcdse/services/databases.dart';
import 'package:mcdse/services/local_content_resolver.dart';
import 'package:mcdse/services/settings_store.dart';
import 'package:mcdse/theme.dart';
import 'package:mcdse/ui/screens/equipment_screen.dart';
import 'package:mcdse/ui/screens/item_list_screen.dart';
import 'package:mcdse/ui/windows/selection_window.dart';
import 'package:mcdse/viewmodels/main_equipment_view_model.dart';

class _StubResolver extends LocalContentResolver {
  _StubResolver(this.png);
  final Uint8List png;
  @override
  Uint8List? imageSourceForItemType(String itemType) => png;
}

Property<ProfileSaveFile?> _profileProp() =>
    Property<ProfileSaveFile?>(ProfileSaveFile({
      'items': <Map<String, dynamic>>[],
      'storageChestItems': <Map<String, dynamic>>[],
      'xp': 0,
    }));

Widget _wrap(Widget child) => MaterialApp(
      theme: buildThemeData(AppTheme.dark),
      home: Scaffold(body: child),
    );

void main() {
  late Uint8List png;
  late IImageResolver originalResolver;

  setUpAll(() {
    SettingsStore.disableIo();
    png = File('assets/images/Armor.png').readAsBytesSync();
    originalResolver = ImageResolver.instance;
    ImageResolver.instance = _StubResolver(png);
    AppModel.gameContentLoaded = true;
    ItemDatabase.all.addAll(['Axe', 'Battlestaff', 'Sword', 'Bow']);
    ItemDatabase.meleeWeapons.addAll(['Axe', 'Battlestaff', 'Sword']);
    ItemDatabase.rangedWeapons.add('Bow');
  });

  tearDownAll(() {
    ImageResolver.instance = originalResolver;
    AppModel.gameContentLoaded = false;
    ItemDatabase.all.clear();
    ItemDatabase.meleeWeapons.clear();
    ItemDatabase.rangedWeapons.clear();
  });

  testWidgets('inventory "+" opens item picker and adds the picked type',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prop = _profileProp();
    final vm = MainEquipmentViewModel(prop);
    await tester.pumpWidget(_wrap(ItemListScreen(model: vm)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+').last);
    await tester.pumpAndSettle();
    expect(find.byType(SelectionWindow), findsOneWidget);

    await tester.tap(find.text('Axe').first);
    await tester.pumpAndSettle();
    expect(prop.value!.items, hasLength(1));
    expect(prop.value!.items!.single.type, 'Axe');
    expect(prop.value!.items!.single.markedNew, true);
  });

  testWidgets('empty equipment slot "+" opens filtered picker',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prop = _profileProp();
    final vm = MainEquipmentViewModel(prop);
    await tester.pumpWidget(_wrap(Center(
      child: SizedBox(
          width: 700, height: 500, child: EquipmentScreen(model: vm)),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+').first);
    await tester.pumpAndSettle();
    expect(find.byType(SelectionWindow), findsOneWidget);
    expect(find.text('Axe').first, findsOneWidget);
    expect(find.text('Bow'), findsNothing);

    await tester.tap(find.text('Battlestaff').first);
    await tester.pumpAndSettle();
    expect(prop.value!.items, hasLength(1));
    final added = prop.value!.items!.single;
    expect(added.type, 'Battlestaff');
    expect(added.equipmentSlot, 'MeleeGear');
  });
}

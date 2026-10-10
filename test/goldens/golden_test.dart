import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/app_model.dart';
import 'package:mcdse/data/enums.dart';
import 'package:mcdse/data/models/enchantment.dart';
import 'package:mcdse/data/models/item.dart';
import 'package:mcdse/main.dart';
import 'package:mcdse/services/settings_store.dart';
import 'package:mcdse/theme.dart';
import 'package:mcdse/ui/screens/enchantment_screen.dart';
import 'package:mcdse/ui/widgets/save_picker_dialog.dart';
import 'package:mcdse/ui/windows/about_window.dart';
import 'package:mcdse/ui/windows/game_files_window.dart';
import 'package:mcdse/ui/windows/main_window.dart';
import 'package:mcdse/ui/windows/selection_window.dart';
import 'package:mcdse/ui/windows/splash_window.dart';

const _blankDat =
    '/mnt/other/devinoruim-projects/MCDSaveEdit-upstream/MCDSaveEditTests/TestData/Blank.dat';
const _surface = Size(1280, 800);

Future<ByteData> _sdkFile(String relative) async {
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/$relative',
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    candidates.add('${dir.path}/$relative');
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      return bytes.buffer.asByteData();
    }
  }
  throw StateError('SDK file not found: $relative');
}

Future<void> _loadFonts() async {
  final roboto = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Roboto-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(_sdkFile(
        'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = _surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Boots the real app past the splash into the main window.
Future<AppModel> _bootApp(WidgetTester tester) async {
  final appModel = AppModel();
  await tester.pumpWidget(McdseApp(args: const ['SKIP_GAME_CONTENT'], model: appModel));
  await tester.runAsync(() async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
  expect(find.byType(MainWindow), findsOneWidget);
  return appModel;
}

Future<void> _openBlankSave(WidgetTester tester, AppModel appModel) async {
  await tester.runAsync(() async {
    await appModel.mainModel.handleFileOpenAsync(_blankDat);
    await tester.pump();
  });
}

Widget _themed(Widget child, {AppTheme theme = AppTheme.dark}) {
  return MaterialApp(
    theme: buildThemeData(theme),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SettingsStore.disableIo();
    await _loadFonts();
  });

  testWidgets('splash window', (tester) async {
    await _setSurface(tester);
    await tester.pumpWidget(_themed(const SplashWindow()));
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
        find.byType(SplashWindow), matchesGoldenFile('goldens/splash_window.png'));
  });

  testWidgets('game files dialog', (tester) async {
    await _setSurface(tester);
    await tester.pumpWidget(_themed(Builder(
      builder: (ctx) => Center(
        child: ElevatedButton(
          onPressed: () => GameFilesWindow.show(ctx),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(GameFilesWindow), matchesGoldenFile('goldens/game_files_dialog.png'));
  });

  testWidgets('main window empty save (dark)', (tester) async {
    await _setSurface(tester);
    final appModel = await _bootApp(tester);
    await _openBlankSave(tester, appModel);
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/main_window_dark.png'));
  });

  testWidgets('main window light theme', (tester) async {
    await _setSurface(tester);
    ThemeController.theme.setValue = AppTheme.light;
    addTearDown(() => ThemeController.theme.setValue = AppTheme.dark);
    final appModel = await _bootApp(tester);
    await _openBlankSave(tester, appModel);
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/main_window_light.png'));
  });

  testWidgets('main window oled theme', (tester) async {
    await _setSurface(tester);
    ThemeController.theme.setValue = AppTheme.oled;
    addTearDown(() => ThemeController.theme.setValue = AppTheme.dark);
    final appModel = await _bootApp(tester);
    await _openBlankSave(tester, appModel);
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/main_window_oled.png'));
  });

  testWidgets('inventory with item selected', (tester) async {
    await _setSurface(tester);
    final appModel = await _bootApp(tester);
    await _openBlankSave(tester, appModel);
    final equipment = appModel.mainModel.profileModel.mainEquipmentModel;
    final item = Item.fromFields(
      type: 'Sword',
      power: 12.5,
      rarity: Rarity.rare,
      markedNew: true,
      enchantments: [Enchantment.fromFields(id: 'Sharpness', level: 2)],
    );
    equipment.addItemToList(item);
    equipment.selectItem(item);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/inventory_item_selected.png'));
  });

  testWidgets('stats tab', (tester) async {
    await _setSurface(tester);
    final appModel = await _bootApp(tester);
    await _openBlankSave(tester, appModel);
    await tester.tap(find.text('Stats/Counters'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/stats_tab.png'));
  });

  testWidgets('storage chest tab', (tester) async {
    await _setSurface(tester);
    final appModel = await _bootApp(tester);
    await _openBlankSave(tester, appModel);
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/chest_tab.png'));
  });

  testWidgets('about dialog', (tester) async {
    await _setSurface(tester);
    await tester.pumpWidget(_themed(Builder(
      builder: (ctx) => Center(
        child: ElevatedButton(
          onPressed: () => AboutWindow.show(ctx),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(AlertDialog), matchesGoldenFile('goldens/about_dialog.png'));
  });

  testWidgets('save picker dialog', (tester) async {
    await _setSurface(tester);
    final dir = Directory('test/goldens/tmp_saves')..createSync();
    final f1 = File('${dir.path}/savefile.dat')..createSync();
    final f2 = File('${dir.path}/E0E9D56B464E7BB914E79991DB607E49.dat')
      ..createSync();
    final fixed = DateTime(2026, 10, 9, 21, 13);
    f1.setLastModifiedSync(fixed);
    f2.setLastModifiedSync(fixed);
    addTearDown(() => dir.deleteSync(recursive: true));

    await tester.pumpWidget(_themed(SavePickerDialog(saves: [f1, f2])));
    await tester.pumpAndSettle();
    await expectLater(find.byType(SavePickerDialog),
        matchesGoldenFile('goldens/save_picker_dialog.png'));
  });

  testWidgets('enchantment screen', (tester) async {
    await _setSurface(tester);
    final enchant = Enchantment.fromFields(id: 'Sharpness', level: 2);
    await tester.pumpWidget(_themed(Center(
      child: SizedBox(
        width: 400,
        height: 400,
        child: EnchantmentScreen(enchantment: enchant, isGilded: false),
      ),
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(EnchantmentScreen),
        matchesGoldenFile('goldens/enchantment_screen.png'));
  });

  testWidgets('selection window', (tester) async {
    await _setSurface(tester);
    await tester.pumpWidget(_themed(Builder(
      builder: (ctx) => Center(
        child: ElevatedButton(
          onPressed: () => SelectionWindow.showItems(ctx, null),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(SelectionWindow),
        matchesGoldenFile('goldens/selection_window.png'));
  });
}

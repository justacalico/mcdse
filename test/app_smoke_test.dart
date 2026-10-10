import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/app_model.dart';
import 'package:mcdse/main.dart';
import 'package:mcdse/services/settings_store.dart';
import 'package:mcdse/ui/windows/main_window.dart';
import 'package:mcdse/ui/windows/splash_window.dart';
import 'package:mcdse/ui/tabs/inventory_tab.dart';
import 'package:mcdse/ui/screens/item_list_screen.dart';
import 'package:mcdse/ui/screens/equipment_screen.dart';
import 'package:mcdse/ui/screens/item_screen.dart';

const _blankDat =
    '/mnt/other/devinoruim-projects/MCDSaveEdit-upstream/MCDSaveEditTests/TestData/Blank.dat';

void main() {
  setUpAll(() {
    SettingsStore.disableIo();
  });

  testWidgets('app boots to splash then main window (SKIP_GAME_CONTENT)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const McdseApp(args: ['SKIP_GAME_CONTENT']));
    // Splash visible first.
    expect(find.byType(SplashWindow), findsOneWidget);

    // BusyIndicator animates forever so pumpAndSettle never completes.
    // runAsync lets the real file IO in the startup path resolve.
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    expect(find.byType(MainWindow), findsOneWidget);
    expect(find.text('File'), findsWidgets);
    expect(find.text('About'), findsWidgets);
  });

  testWidgets('opening Blank.dat shows inventory + items', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    final appModel = AppModel();
    final app = McdseApp(args: const ['SKIP_GAME_CONTENT'], model: appModel);
    await tester.pumpWidget(app);
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await appModel.mainModel.handleFileOpenAsync(_blankDat);
      await tester.pump();
    });

    expect(find.byType(MainWindow), findsOneWidget);
    expect(find.byType(InventoryTab), findsOneWidget);
    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(find.byType(EquipmentScreen), findsOneWidget);
    expect(find.byType(ItemScreen), findsOneWidget);
  });

  test('main window model flow: open -> profile -> tabs', () async {
    final appModel = AppModel();
    appModel.mainModel.showError = (m) => fail('showError: $m');
    await appModel.mainModel.handleFileOpenAsync(_blankDat);
    expect(appModel.mainModel.profileModel.profile.value, isNotNull);
    // Blank.dat has an empty currency array, so emeralds is null.
    expect(appModel.mainModel.profileModel.filePath, _blankDat);

    // Save to a temp .json (decrypted) then .dat (encrypted) — round trip.
    final dir = Directory.systemTemp.createTempSync('mcdse_test');
    final jsonPath = '${dir.path}/blank.json';
    final datPath = '${dir.path}/blank.dat';
    await appModel.mainModel
        .handleFileSaveAsync(jsonPath, appModel.mainModel.profileModel.profile.value!);
    expect(File(jsonPath).existsSync(), true);
    await appModel.mainModel
        .handleFileSaveAsync(datPath, appModel.mainModel.profileModel.profile.value!);
    final datBytes = File(datPath).readAsBytesSync();
    // Encrypted files carry the D001 magic header.
    expect(datBytes.sublist(0, 4), [0x44, 0x30, 0x30, 0x31]);

    // Reopen the decrypted file.
    final appModel2 = AppModel();
    await appModel2.mainModel.handleFileOpenAsync(jsonPath);
    expect(appModel2.mainModel.profileModel.profile.value, isNotNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/main.dart';
import 'package:mcdse/services/settings_store.dart';
import 'package:mcdse/theme.dart';
import 'package:mcdse/ui/widgets/custom_title_bar.dart';
import 'package:mcdse/ui/windows/main_window.dart';

void main() {
  setUpAll(() => SettingsStore.disableIo());

  group('ThemeController', () {
    test('specifier round-trip and persistence', () {
      SettingsStore.reset();
      ThemeController.setTheme(AppTheme.oled);
      expect(ThemeController.theme.value, AppTheme.oled);
      expect(SettingsStore.getSetting(AppTheme.specifierKey, ''), 'oled');

      ThemeController.setTheme(AppTheme.light);
      expect(SettingsStore.getSetting(AppTheme.specifierKey, ''), 'light');

      ThemeController.setTheme(AppTheme.dark);
      expect(SettingsStore.getSetting(AppTheme.specifierKey, ''), 'dark');
    });

    test('fromSpecifier defaults to dark', () {
      expect(AppTheme.fromSpecifier('garbage'), AppTheme.dark);
      expect(AppTheme.fromSpecifier('oled'), AppTheme.oled);
      expect(AppTheme.fromSpecifier('light'), AppTheme.light);
    });

    test('oled theme uses true black surfaces', () {
      final oled = buildThemeData(AppTheme.oled);
      expect(oled.scaffoldBackgroundColor, Colors.black);
      expect(oled.colorScheme.surface, Colors.black);
      final dark = buildThemeData(AppTheme.dark);
      expect(dark.scaffoldBackgroundColor, isNot(Colors.black));
    });
  });

  testWidgets('custom title bar renders with app title', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const McdseApp(args: ['SKIP_GAME_CONTENT']));
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    expect(find.byType(CustomTitleBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.minimize), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.text('Minecraft Dungeons Save File Editor'), findsWidgets);
    expect(find.byType(MainWindow), findsOneWidget);
  });
}

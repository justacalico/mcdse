import 'package:flutter/material.dart';

import 'core/property.dart';
import 'services/settings_store.dart';

/// App theme options shown in the Theme menu.
enum AppTheme {
  light,
  dark,
  oled;

  static const String specifierKey = 'ThemeSpecifier';

  String get specifier => switch (this) {
        AppTheme.light => 'light',
        AppTheme.dark => 'dark',
        AppTheme.oled => 'oled',
      };

  static AppTheme fromSpecifier(String specifier) => switch (specifier) {
        'light' => AppTheme.light,
        'oled' => AppTheme.oled,
        _ => AppTheme.dark,
      };
}

/// Theme data for each mode. OLED is a true-black variant of dark.
ThemeData buildThemeData(AppTheme theme) {
  const seedColor = Color(0xFF4CAF50);
  final base = ThemeData(
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: theme == AppTheme.light
            ? Brightness.light
            : Brightness.dark),
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
  );
  if (theme != AppTheme.oled) return base;

  // OLED: pure black surfaces so the UI floats on true black.
  final darkScheme = base.colorScheme;
  return base.copyWith(
    scaffoldBackgroundColor: Colors.black,
    cardColor: const Color(0xFF0A0A0A),
    dividerColor: const Color(0xFF1E1E1E),
    colorScheme: darkScheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF101010),
      surfaceContainerHigh: const Color(0xFF161616),
      surfaceContainerHighest: const Color(0xFF1E1E1E),
    ), dialogTheme: DialogThemeData(backgroundColor: Colors.black),
  );
}

/// Global theme controller — persisted via [SettingsStore].
abstract final class ThemeController {
  static const AppTheme defaultTheme = AppTheme.dark;

  static final Property<AppTheme> _theme = Property(defaultTheme);
  static IReadWriteProperty<AppTheme> get theme => _theme;

  /// Restores the saved theme (call once before `runApp`).
  static void init() {
    final saved = SettingsStore.getSetting(
        AppTheme.specifierKey, defaultTheme.specifier);
    _theme.setValue = AppTheme.fromSpecifier(saved);
  }

  static void setTheme(AppTheme theme) {
    _theme.setValue = theme;
    SettingsStore.saveSetting(AppTheme.specifierKey, theme.specifier);
  }
}

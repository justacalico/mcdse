import 'dart:convert';
import 'dart:io';

/// Cross-platform replacement for upstream's Windows-registry `RegistryTools`.
/// Settings are persisted to a JSON file in the app config directory; an
/// in-memory mode is used for tests and platforms without dart:io.
class SettingsStore {
  SettingsStore._();

  static final SettingsStore instance = SettingsStore._();

  /// Optional file path override (tests).
  static String? overrideFilePath;

  /// In-memory store used before the file is loaded or when IO is disabled.
  static final Map<String, String> _memory = <String, String>{};
  static bool _loaded = false;
  static bool _ioDisabled = false;

  /// Disable file IO entirely (tests / web).
  static void disableIo([bool disabled = true]) => _ioDisabled = disabled;

  static String get _filePath {
    if (overrideFilePath != null) return overrideFilePath!;
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? home;
      return '$appData\\MCDSaveEdit\\settings.json';
    }
    return '$home/.config/mcdsaveedit/settings.json';
  }

  static void _load() {
    if (_loaded || _ioDisabled) return;
    try {
      final file = File(_filePath);
      if (file.existsSync()) {
        final decoded = json.decode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          _memory.addAll(decoded.map((k, v) => MapEntry(k, '$v')));
        }
      }
    } catch (_) {
      // A corrupt settings file is not fatal.
    }
    _loaded = true;
  }

  static void _save() {
    if (_ioDisabled) return;
    try {
      final file = File(_filePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_memory));
    } catch (_) {
      // Persisting settings is best-effort.
    }
  }

  static void saveSetting(String name, Object value) {
    _load();
    _memory[name] = '$value';
    _save();
  }

  static String getSetting(String name, String defaultValue) {
    _load();
    return _memory[name] ?? defaultValue;
  }

  static void deleteSetting(String name) {
    _load();
    _memory.remove(name);
    _save();
  }

  /// Test helper: clear everything.
  static void reset() {
    _memory.clear();
    _loaded = false;
    _ioDisabled = false;
    overrideFilePath = null;
  }
}

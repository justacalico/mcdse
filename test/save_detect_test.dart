import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/data/constants.dart';
import 'package:mcdse/services/settings_store.dart';

void main() {
  test('detects proton save dir', () async {
    SettingsStore.overrideFilePath = '/tmp/mcdse_test_settings.json';
    final dirs = Constants.detectedSaveDirectories();
    print('dirs: $dirs');
    final files = Constants.detectedSaveFiles();
    for (final f in files) print('  ${f.path}  ${f.lastModifiedSync()}');
    if (Directory('/mnt/FuckBTRFS/SteamLibrary/steamapps/compatdata/1672970').existsSync()) {
      expect(dirs, isNotEmpty);
      expect(files, isNotEmpty);
    }
  });
}

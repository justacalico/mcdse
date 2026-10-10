import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/app_model.dart';
import 'package:mcdse/services/databases.dart';

// Integration test against a real Minecraft Dungeons install.
// Skipped automatically when the game isn't present.
const _paksPath = '/mnt/FuckBTRFS/SteamLibrary/steamapps/common/MinecraftDungeons/Dungeons/Content/Paks';
final _hasPaks = Directory(_paksPath).existsSync();

void main() {
  test(
    'loads real game content (index, locres, textures)',
    () async {
      final model = AppModel();
      await model.loadGameContent(_paksPath);
      final resolver = AppModel.pakContentResolver!;

      expect(resolver.localizationOptions, contains('en'));
      expect(ItemDatabase.armorProperties.length, greaterThan(30));
      expect(resolver.levels.length, greaterThan(50));

      // re-scanning must not duplicate level entries
      resolver.loadPakFiles();
      expect(resolver.levels.length, greaterThan(50));

      final lib = resolver.loadLanguageStrings('en');
      expect(lib, isNotNull);
      final flat = {for (final e in lib!.entries) ...e.value};
      expect(flat.length, greaterThan(4000));

      for (final type in ['Sword_Steel', 'MercenaryArmor', 'Glaive']) {
        expect(resolver.imageSourceForItemType(type), isNotNull,
            reason: type);
      }
      expect(resolver.imageSourceForEnchantmentId('Sharpness'), isNotNull);
    },
    skip: !_hasPaks,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

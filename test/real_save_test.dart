// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/logic/file_process_helper.dart';
import 'package:mcdse/data/profile_parser.dart';
import 'package:mcdse/logic/extensions.dart';

const _realSave =
    '/mnt/FuckBTRFS/SteamLibrary/steamapps/compatdata/1672970/pfx/drive_c/users/steamuser/Saved Games/Mojang Studios/Dungeons/2535446877323841/Characters/E0E9D56B464E7BB914E79991DB607E49.dat';
final _hasRealSave = File(_realSave).existsSync();

void main() {
  test('real save decrypt+parse', () async {
    final data = await FileProcessHelper.decrypt(
        File(_realSave).readAsBytesSync());
    expect(data, isNotNull);
    final save = ProfileParser.read(data!);
    expect(save, isNotNull);
    final s = save!;
    print('items: ${s.items?.length}');
    print('xp=${s.xp} level=${s.level()}');
    for (final i in s.items ?? []) {
      print('  - ${i.type} idx=${i.inventoryIndex} slot=${i.equipmentSlot} power=${i.power}');
    }
    print('currencies: ${s.currency?.map((c)=>"${c.type}=${c.count}").toList()}');
    print('difficulties: ${s.json.keys.toList().take(20)}');
  }, skip: !_hasRealSave);
}

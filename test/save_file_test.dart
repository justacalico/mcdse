import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/data/profile_parser.dart';
import 'package:mcdse/logic/extensions.dart';
import 'package:mcdse/logic/file_process_helper.dart';
import 'package:mcdse/services/save_file_handler.dart';

void main() {
  test('Blank.dat decrypts and parses', () async {
    final bytes =
        await File('test/data/Blank.dat').readAsBytes();
    expect(SaveFileHandler.isFileEncrypted(bytes), true);
    final decrypted = await FileProcessHelper.decrypt(bytes);
    expect(decrypted, isNotNull);
    final profile = ProfileParser.read(decrypted!);
    expect(profile, isNotNull);
    expect(profile!.isValid(), true);
    expect(profile.xp, 0);
    expect(profile.skin, 'steve');
  });

  test('encrypt produces a file that decrypts back', () async {
    final bytes = await File('test/data/Blank.dat').readAsBytes();
    final decrypted = (await FileProcessHelper.decrypt(bytes))!;
    final reEncrypted = (await FileProcessHelper.encrypt(decrypted))!;
    expect(SaveFileHandler.isFileEncrypted(reEncrypted), true);
    final roundTrip = (await FileProcessHelper.decrypt(reEncrypted))!;
    final p1 = ProfileParser.read(decrypted)!;
    final p2 = ProfileParser.read(roundTrip)!;
    expect(p1.json['playerId'], p2.json['playerId']);
  });
}

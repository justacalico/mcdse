import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/services/save_file_watcher.dart';

void main() {
  late Directory dir;
  late File save;
  late SaveFileWatcher watcher;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mcdse_watch');
    save = File('${dir.path}/char.json')..writeAsStringSync('{"items":[]}');
    watcher = SaveFileWatcher(debounce: const Duration(milliseconds: 50));
  });

  tearDown(() {
    watcher.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<void> pump() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  test('fires once for an external write', () async {
    var fired = 0;
    watcher.watch(save.path, (_) => fired++);
    save.writeAsStringSync('{"items":[1]}');
    await pump();
    expect(fired, 1);
  });

  test('debounces a burst of writes into one callback', () async {
    var fired = 0;
    watcher.watch(save.path, (_) => fired++);
    for (var i = 0; i < 5; i++) {
      save.writeAsStringSync('{"i":$i}');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await pump();
    expect(fired, 1);
  });

  test('ignores the app\'s own write after markSelfWrite', () async {
    var fired = 0;
    watcher.watch(save.path, (_) => fired++);
    save.writeAsStringSync('{"items":[2]}');
    watcher.markSelfWrite(save.path);
    await pump();
    expect(fired, 0);
    save.writeAsStringSync('{"items":[3]}');
    await pump();
    expect(fired, 1);
  });

  test('dispose stops callbacks', () async {
    var fired = 0;
    watcher.watch(save.path, (_) => fired++);
    watcher.dispose();
    save.writeAsStringSync('{"items":[4]}');
    await pump();
    expect(fired, 0);
  });

  test('watch on a missing file does not throw or fire', () async {
    var fired = 0;
    watcher.watch('${dir.path}/nope.json', (_) => fired++);
    await pump();
    expect(fired, 0);
  });
}

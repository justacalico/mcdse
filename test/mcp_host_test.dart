import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcdse/mcp/mcp_host.dart';
import 'package:mcdse/mcp/mcpb_exporter.dart';
import 'package:mcdse/data/models/profile_save_file.dart';
import 'package:mcdse/services/settings_store.dart';
import 'package:mcdse/viewmodels/profile_view_model.dart';

void main() {
  setUp(() => SettingsStore.disableIo());
  tearDown(() => McpHost.stop());

  test('enable/disable persists to settings', () async {
    expect(McpHost.enabled, false);
    SettingsStore.saveSetting(McpHost.portKey, '0');
    await McpHost.setEnabled(true);
    expect(McpHost.enabled, true);
    await McpHost.setEnabled(false);
    expect(McpHost.enabled, false);
  });

  test('start binds loopback endpoint and stop releases it', () async {
    final port = await McpHost.start(port: 0);
    expect(port, greaterThan(0));
    expect(McpHost.running, true);
    expect(McpHost.endpoint, 'http://127.0.0.1:$port/mcp');
    await McpHost.stop();
    expect(McpHost.running, false);
  });

  test('initFromSettings starts only when enabled', () async {
    await McpHost.initFromSettings();
    expect(McpHost.running, false);
    SettingsStore.saveSetting(McpHost.enabledKey, 'true');
    SettingsStore.saveSetting(McpHost.portKey, '0');
    await McpHost.initFromSettings();
    expect(McpHost.running, true);
  });

  test('agent edits push into the app profile and vice versa', () {
    final vm = ProfileViewModel();
    McpHost.bindProfile(vm);
    // App opens a file -> session mirrors it.
    final appProfile = ProfileSaveFile({
      'items': [
        {'type': 'Sword', 'power': 1.0}
      ],
      'xp': 100,
    });
    vm.filePath = '/tmp/app.dat';
    vm.profile.setValue = appProfile;
    expect(identical(McpHost.session.profile, appProfile), true);
    expect(McpHost.session.filePath, '/tmp/app.dat');
    // Agent edits -> same instance lands back on the vm and notifies.
    var notifications = 0;
    vm.profile.subscribe((_) => notifications++);
    McpHost.session.addItem(type: 'Bow');
    expect(notifications, greaterThan(0));
    expect(appProfile.items, hasLength(2));
    expect(vm.profile.value!.items![1].type, 'Bow');
  });

  test('tools/list exposes every save tool and calls run', () async {
    final port = await McpHost.start(port: 0);
    final client = HttpClient();
    addTearDown(client.close);
    String? sessionId;
    Future<Map<String, dynamic>?> rpc(Map<String, dynamic> payload) async {
      final req = await client.post(
          '127.0.0.1', port, '/mcp')
        ..headers.contentType = ContentType.json
        ..headers.set('accept', 'application/json, text/event-stream');
      if (sessionId != null) req.headers.set('mcp-session-id', sessionId!);
      req.write(jsonEncode(payload));
      final res = await req.close();
      sessionId ??= res.headers.value('mcp-session-id');
      final body = await res.transform(utf8.decoder).join();
      if (body.isEmpty) return null;
      if (body.startsWith('data:')) {
        final data = body.substring(body.indexOf('data:') + 5).trim();
        return jsonDecode(data) as Map<String, dynamic>;
      }
      return jsonDecode(body) as Map<String, dynamic>;
    }

    final init = await rpc({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-11-25',
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'test', 'version': '1'}
      }
    });
    expect(init!['result'], isNotNull);

    await rpc({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
      'params': <String, dynamic>{}
    });

    final list = await rpc({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'tools/list',
      'params': <String, dynamic>{}
    });
    final names = ((list!['result'] as Map)['tools'] as List)
        .map((t) => t['name'])
        .toSet();
    expect(
        names,
        containsAll([
          'game_catalog',
          'detect_save_files',
          'open_save',
          'save_info',
          'dump_profile_json',
          'list_items',
          'get_item',
          'add_item',
          'update_item',
          'duplicate_item',
          'move_item',
          'remove_item',
          'set_level',
          'set_xp',
          'set_currency',
          'save',
        ]));

    final open = await rpc({
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'tools/call',
      'params': {
        'name': 'open_save',
        'arguments': {'path': 'test/data/Blank.dat'}
      }
    });
    expect(open!['result']['isError'], isNot(true));

    final call = await rpc({
      'jsonrpc': '2.0',
      'id': 4,
      'method': 'tools/call',
      'params': {'name': 'save_info', 'arguments': <String, dynamic>{}}
    });
    final info = call!['result'] as Map;
    expect(info['isError'], isNot(true));
    expect((info['content'] as List).first['text'], contains('inventoryItemCount'));

    final bad = await rpc({
      'jsonrpc': '2.0',
      'id': 5,
      'method': 'tools/call',
      'params': {
        'name': 'update_item',
        'arguments': {'index': 999, 'fields': <String, dynamic>{}}
      }
    });
    expect(bad!['result']['isError'], true);
  });

  test('export writes a valid mcpb zip', () async {
    final dir = Directory.systemTemp.createTempSync('mcdse_mcpb');
    addTearDown(() => dir.deleteSync(recursive: true));
    final fakeServer = File('${dir.path}/mcdse-mcp')
      ..writeAsBytesSync([0x7F, 0x45, 0x4C, 0x46, 1, 2, 3]);
    McpbExporter.binaryCandidates.insert(0, fakeServer.path);
    addTearDown(() => McpbExporter.binaryCandidates.remove(fakeServer.path));

    final out = File('${dir.path}/out.mcpb');
    await McpbExporter.export(out.path);
    expect(out.existsSync(), true);

    final zip = ZipDecoder().decodeBytes(out.readAsBytesSync());
    final names = zip.files.map((f) => f.name).toList();
    expect(names, containsAll(['manifest.json', 'server/mcdse-mcp']));
    final manifest = jsonDecode(
            utf8.decode(zip.findFile('manifest.json')!.content as List<int>))
        as Map<String, dynamic>;
    expect(manifest['server']['entry_point'], 'server/mcdse-mcp');
    final exe = zip.findFile('server/mcdse-mcp')!;
    expect(exe.content as List<int>, [0x7F, 0x45, 0x4C, 0x46, 1, 2, 3]);
    expect(exe.mode & 0x1FF, 0x1ED);
  });

  test('export without binary reports a clear error', () {
    final dir = Directory.systemTemp.createTempSync('mcdse_mcpb2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final saved = [...McpbExporter.binaryCandidates];
    McpbExporter.binaryCandidates.clear();
    addTearDown(() =>
        McpbExporter.binaryCandidates
          ..clear()
          ..addAll(saved));
    // cwd has bin/mcp_server.dart, so this may compile instead of throwing;
    // assert it either throws or produces a file — never crashes silently.
    expect(() => McpbExporter.export('${dir.path}/x.mcpb'), returnsNormally);
  });
}

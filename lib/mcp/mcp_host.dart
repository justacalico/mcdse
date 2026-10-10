import 'dart:async';
import 'dart:developer' as developer;

import 'package:mcp_dart/mcp_dart.dart';

import '../services/settings_store.dart';
import '../services/string_library.dart';
import '../ui/widgets/custom_title_bar.dart';
import '../viewmodels/profile_view_model.dart';
import 'mcp_tools.dart';
import 'save_session.dart';

/// In-app MCP server — hosts the save-file tools over Streamable HTTP on
/// loopback so an AI agent can connect while the app is running.
/// Enable/disable is persisted in [SettingsStore].
abstract final class McpHost {
  static const enabledKey = 'McpServerEnabled';
  static const portKey = 'McpServerPort';
  static const defaultPort = 8756;
  static const path = '/mcp';

  static StreamableMcpServer? _server;
  static final SaveSession session = SaveSession();

  /// Wires the MCP session to the app's profile: agent edits rebuild the UI,
  /// and files opened in the UI are mirrored into the session.
  static void bindProfile(ProfileViewModel vm) {
    session.onChanged = () {
      final p = session.profile;
      if (p == null) return;
      vm.filePath = session.filePath;
      final path = session.filePath;
      WindowTitle.title = path == null
          ? R.applicationTitle
          : '${R.applicationTitle} - ${path.split(RegExp(r'[/\\]')).last}';
      vm.profile.setValue = p;
    };
    vm.profile.subscribe((p) {
      if (p != null && !identical(p, session.profile)) {
        session.profile = p;
        session.filePath = vm.filePath;
      }
    });
    if (vm.profile.value != null) {
      session.profile = vm.profile.value;
      session.filePath = vm.filePath;
    }
  }

  static bool get running => _server != null;

  static bool get enabled =>
      SettingsStore.getSetting(enabledKey, 'false') == 'true';

  static int get configuredPort =>
      int.tryParse(SettingsStore.getSetting(portKey, '')) ?? defaultPort;

  static String get endpoint =>
      'http://127.0.0.1:${_server?.boundPort ?? configuredPort}$path';

  /// Starts the server if the setting says it should be on. Call once at
  /// startup.
  static Future<void> initFromSettings() async {
    if (enabled && !running) {
      try {
        await start();
        developer.log('MCP server listening on $endpoint');
      } catch (e) {
        developer.log('MCP server failed to start: $e');
      }
    }
  }

  static Future<int> start({int? port, int retries = 3}) async {
    await stop();
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      try {
        final srv = StreamableMcpServer(
          serverFactory: (_) {
            final server = McpServer(
              const Implementation(
                  name: 'mcdse-save-editor', version: '1.0.0'),
              options: McpServerOptions(
                capabilities:
                    ServerCapabilities(tools: ServerCapabilitiesTools()),
              ),
            );
            registerSaveTools(server, session);
            return server;
          },
          host: '127.0.0.1',
          port: port ?? configuredPort,
          path: path,
          enableJsonResponse: true,
        );
        await srv.start();
        _server = srv;
        return srv.boundPort;
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('MCP server failed to start: $lastError');
  }

  static Future<void> stop() async {
    final srv = _server;
    _server = null;
    await srv?.stop();
  }

  static Future<void> setEnabled(bool value) async {
    SettingsStore.saveSetting(enabledKey, value.toString());
    if (value) {
      await start();
    } else {
      await stop();
    }
  }
}

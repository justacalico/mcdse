import 'dart:developer' as developer;

import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcdse/data/constants.dart';
import 'package:mcdse/data/secrets.dart';
import 'package:mcdse/mcp/mcp_tools.dart';
import 'package:mcdse/mcp/save_session.dart';
import 'package:mcdse/pak/binary_reader.dart';
import 'package:mcdse/pak/pak_filter.dart';
import 'package:mcdse/pak/pak_index.dart';
import 'package:mcdse/pak/objects.dart';
import 'package:mcdse/services/pak_content_resolver.dart';
import 'package:mcdse/services/string_library.dart';

/// Loads the pak catalog so item/enchant ids validate and names resolve —
/// the same scan the app does at startup. Best-effort: no paks, no catalog.
Future<void> _loadCatalog() async {
  for (final dir in Constants.detectedPakDirectories()) {
    try {
      final pakIndex = PakIndex(
          path: dir,
          cacheFiles: true,
          caseSensitive: true,
          filter: PakFilter([Constants.paksFilterString],
              caseSensitive: false));
      if (pakIndex.pakFileCount == 0) continue;
      var unlocked = false;
      for (final key in Secrets.pakAesKeys) {
        final keyStr =
            key.key.startsWith('0x') ? key.key.substring(2) : key.key;
        if (pakIndex.useKey(hexToBytes(keyStr), FGuid.zero) > 0) {
          unlocked = true;
          break;
        }
      }
      if (!unlocked) continue;
      final resolver = PakContentResolver(pakIndex, dir);
      resolver.loadPakFiles();
      final strings = resolver
          .loadLanguageStrings(Constants.defaultLangSpecifier);
      if (strings != null) R.loadExternalStrings(strings);
      developer.log('Loaded game catalog from $dir');
      return;
    } catch (_) {}
  }
}

/// MCP stdio server exposing Minecraft Dungeons save-file tools to AI agents.
/// Build with: dart build cli -t bin/mcp_server.dart
Future<void> main() async {
  await _loadCatalog();
  final server = McpServer(
    const Implementation(name: 'mcdse-save-editor', version: '1.0.0'),
    options: McpServerOptions(
      capabilities: ServerCapabilities(tools: ServerCapabilitiesTools()),
    ),
  );
  registerSaveTools(server, SaveSession());
  await server.connect(StdioServerTransport());
}

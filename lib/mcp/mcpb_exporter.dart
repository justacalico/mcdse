import 'dart:io';

import 'package:archive/archive.dart';

/// Builds an `.mcpb` bundle (manifest.json + compiled server binary) as raw
/// zip bytes. Used by the MCP menu's "Export .mcpb" action.
abstract final class McpbExporter {
  static const _fallbackManifest = '''
{
  "manifest_version": "0.1",
  "name": "mcdse-save-editor",
  "display_name": "Minecraft Dungeons Save Editor",
  "version": "1.0.0",
  "description": "Read and edit Minecraft Dungeons character save files (.dat encrypted / .json).",
  "author": {
    "name": "HttpAnimations",
    "url": "https://gitlab.com/HttpAnimations/mcdse"
  },
  "server": {
    "type": "binary",
    "entry_point": "server/mcdse-mcp",
    "mcp_config": {
      "command": "\${__dirname}/server/mcdse-mcp",
      "args": []
    }
  },
  "license": "MIT"
}
''';

  /// Where a prebuilt server binary can be found. The first existing path
  /// wins; tests can append candidates.
  static final List<String> binaryCandidates = [
    'mcpb/server/mcdse-mcp',
    'mcpb/build/bundle/bin/mcp_server',
  ];

  /// Exported for tests — the manifest source read by [build].
  static String manifestText() {
    const candidates = ['mcpb/manifest.json'];
    for (final path in candidates) {
      final file = File(path);
      if (file.existsSync()) return file.readAsStringSync();
    }
    return _fallbackManifest;
  }

  /// Locates or builds the server binary. Throws [StateError] with
  /// instructions when nothing can produce one.
  static Future<List<int>> _serverBinary() async {
    for (final path in binaryCandidates) {
      final file = File(path);
      if (file.existsSync()) return file.readAsBytes();
    }
    // Try compiling on the fly when running inside a project checkout.
    if (File('bin/mcp_server.dart').existsSync()) {
      final out =
          Directory.systemTemp.createTempSync('mcdse_mcpb_build');
      try {
        final result = await Process.run(
            'dart', ['build', 'cli', '-t', 'bin/mcp_server.dart', '-o', out.path],
            workingDirectory: Directory.current.path);
        final exe = File('${out.path}/bundle/bin/mcp_server');
        if (result.exitCode == 0 && exe.existsSync()) {
          return await exe.readAsBytes();
        }
      } catch (_) {} finally {
        out.deleteSync(recursive: true);
      }
    }
    throw StateError(
        'No MCP server binary available. Run ./mcpb/build_mcpb.sh first, '
        'then export again.');
  }

  /// Writes a complete `.mcpb` to [outputPath].
  static Future<File> export(String outputPath) async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('manifest.json', manifestText()));
    final binary = await _serverBinary();
    archive.addFile(ArchiveFile('server/mcdse-mcp', binary.length, binary)
      ..mode = 0x1ED); // 0755
    final zipped = ZipEncoder().encode(archive);
    final out = File(outputPath);
    await out.writeAsBytes(zipped);
    return out;
  }
}

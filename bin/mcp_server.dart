import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcdse/mcp/mcp_tools.dart';
import 'package:mcdse/mcp/save_session.dart';

/// MCP stdio server exposing Minecraft Dungeons save-file tools to AI agents.
/// Build with: dart build cli -t bin/mcp_server.dart
Future<void> main() async {
  final server = McpServer(
    const Implementation(name: 'mcdse-save-editor', version: '1.0.0'),
    options: McpServerOptions(
      capabilities: ServerCapabilities(tools: ServerCapabilitiesTools()),
    ),
  );
  registerSaveTools(server, SaveSession());
  await server.connect(StdioServerTransport());
}

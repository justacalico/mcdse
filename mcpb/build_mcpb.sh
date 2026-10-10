#!/usr/bin/env bash
# Builds mcdse.mcpb — an MCP bundle installable in MCPB-aware clients.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-mcdse.mcpb}"
rm -rf mcpb/server mcpb/build
dart build cli -t bin/mcp_server.dart -o mcpb/build
mkdir -p mcpb/server
cp mcpb/build/bundle/bin/mcp_server mcpb/server/mcdse-mcp
chmod +x mcpb/server/mcdse-mcp

cd mcpb
zip -r "../$OUT" manifest.json server
cd ..
echo "Built $OUT"

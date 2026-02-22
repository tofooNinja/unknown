#!/usr/bin/env bash
# Run context7 MCP server via npx, using nix shell for Node.js if npx isn't available.
set -e
if command -v npx >/dev/null 2>&1; then
  exec npx -y @upstash/context7-mcp
else
  exec nix shell nixpkgs#nodejs_22 --command npx -y @upstash/context7-mcp
fi

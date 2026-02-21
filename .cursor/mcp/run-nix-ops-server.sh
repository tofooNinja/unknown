#!/usr/bin/env bash
# Prefer system python3 for fast MCP startup (avoids nix eval timeout). Fallback: nix run.
set -e
REPO_ROOT="${NIX_OPS_MCP_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$REPO_ROOT"
if [ "${NIX_OPS_MCP_DEBUG}" = "1" ] || [ "${NIX_OPS_MCP_DEBUG}" = "true" ]; then
  echo "[nix-ops-mcp] wrapper: REPO_ROOT=$REPO_ROOT" >&2
fi
if command -v python3 >/dev/null 2>&1; then
  [ -n "${NIX_OPS_MCP_DEBUG}" ] && echo "[nix-ops-mcp] wrapper: using python3 ($(which python3))" >&2
  exec python3 .cursor/mcp/nix-ops-server.py
else
  [ -n "${NIX_OPS_MCP_DEBUG}" ] && echo "[nix-ops-mcp] wrapper: python3 not in PATH, using nix run" >&2
  exec nix run 'nixpkgs#python3' -- .cursor/mcp/nix-ops-server.py
fi

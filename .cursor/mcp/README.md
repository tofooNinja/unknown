# Nix Ops MCP

Local MCP server for agentic workflows in this repo:

- Nix flake checks and host/installer build commands with structured diagnostics
- Read-only Pi observability (`journalctl`, `dmesg`, `systemctl status`)
- Guarded deploy prototype (`nixos-rebuild test/switch/boot`) with confirmation tokens

## Debug

Set `NIX_OPS_MCP_DEBUG=1` in the server `env` (e.g. in `.cursor/mcp.json`) to enable trace logging. Trace is written to `.cursor/mcp/nix-ops-debug.log` (not stderr) so the MCP panel does not show every line as [error]. Use the debug log to see where the server blocks (e.g. waiting for stdin, config load, or request handling).

## Files

- `nix-ops-server.py` - MCP stdio server implementation
- `nix-ops.config.example.json` - allowlist and safety config template
- `audit.log` - JSONL audit trail (generated at runtime)
- `nix-ops-debug.log` - trace log when `NIX_OPS_MCP_DEBUG=1` (generated at runtime)

## Setup

1. Copy config template:

```bash
cp .cursor/mcp/nix-ops.config.example.json .cursor/mcp/nix-ops.config.json
```

2. Update host IPs/usernames and keep `allowMutations` as `false` until you trust the flow.

3. Wire server into Cursor MCP config. Use the wrapper script so `nixpkgs#python3` is not broken by shell `#` comment parsing:

```json
{
  "mcpServers": {
    "nix-ops": {
      "command": "/path/to/nix-config/.cursor/mcp/run-nix-ops-server.sh",
      "args": [],
      "cwd": "/path/to/nix-config",
      "env": {
        "NIX_OPS_MCP_CONFIG": "/path/to/nix-config/.cursor/mcp/nix-ops.config.json"
      }
    }
  }
}
```

## Tool Overview

- `check_flake(build=false)`
- `list_hosts()`
- `eval_host(hostname)`
- `build_host(hostname, dryRun=true)`
- `build_installer(variant, dryRun=true)`
- `format_check()`
- `parse_nix_error(output)`
- `pi_journal(host, unit?, lines=200, since?)`
- `pi_dmesg(host, lines=200)`
- `pi_service_status(host, unit)`
- `pi_firmware_check(host)` - inspect FIRMWARE partition, config.txt, boot mode
- `pi_uart_console(device?, baudRate=115200, seconds=15, maxBytes=16384, send?)` - discover local `/dev/ttyACM*` + `/dev/ttyUSB*` and capture UART boot logs
- `pi_uart_cache_query(pattern, ignoreCase=false, maxLines=200, device?)` - regex search UART cache
- `pi_uart_cache_range(startLine, endLine)` - fetch inclusive UART cache line range
- `deploy_plan(host, mode=test|switch|boot)`
- `deploy_execute(host, mode, confirmation)`

## UART Notes

- `pi_uart_console` always scans `/dev/ttyACM*` and `/dev/ttyUSB*`.
- If `device` is omitted, the first discovered TTY is used.
- For Pi boot logs, use `baudRate=115200` and increase `seconds` if needed.
- If access is denied, ensure your user has permission for serial devices (often `dialout` group).
- Every `pi_uart_console` capture is appended to a persistent cache (`.cursor/mcp/uart-cache.log` by default).
- Use `pi_uart_cache_query` to find lines matching a regex and `pi_uart_cache_range` for line-number slices.

## Safety Model

- Remote access is blocked unless host exists in `allowedHosts`.
- Observability tools are read-only and command templates are fixed.
- Mutating deploy modes (`switch`, `boot`) require both:
  - `allowMutations: true` in config
  - exact confirmation token from `deploy_plan`
- Every remote/deploy action is written to `audit.log`.

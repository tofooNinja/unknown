#!/usr/bin/env python3
"""
Nix Ops MCP Server

Local MCP server for Nix build/check workflows, read-only Pi observability,
firmware partition inspection, and guarded deploy commands.
"""

from __future__ import annotations

import datetime as dt
import glob
import json
import os
import re
import select
import subprocess
import sys
import termios
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


DEFAULT_CONFIG = ".cursor/mcp/nix-ops.config.json"
DEFAULT_AUDIT_LOG = ".cursor/mcp/audit.log"
DEFAULT_UART_CACHE_LOG = ".cursor/mcp/uart-cache.log"

_DEBUG = os.environ.get("NIX_OPS_MCP_DEBUG", "").lower() in ("1", "true", "yes")

# When debug is on, trace goes to a file so Cursor does not show every line as [error].
_DEBUG_LOG_PATH: Optional[Path] = None


def _get_debug_log_path() -> Optional[Path]:
    global _DEBUG_LOG_PATH
    if _DEBUG_LOG_PATH is not None:
        return _DEBUG_LOG_PATH
    if not _DEBUG:
        return None
    base = Path(os.environ.get("NIX_OPS_MCP_CONFIG", DEFAULT_CONFIG)).resolve().parent
    _DEBUG_LOG_PATH = base / "nix-ops-debug.log"
    return _DEBUG_LOG_PATH


def _log(msg: str) -> None:
    """Normal message: stderr when debug off (Cursor may show as [error]); when debug on, file only to avoid stderr spam."""
    if _DEBUG:
        path = _get_debug_log_path()
        if path:
            try:
                with path.open("a", encoding="utf-8") as f:
                    f.write(f"[nix-ops-mcp] {msg}\n")
            except OSError:
                pass
        return
    print(f"[nix-ops-mcp] {msg}", file=sys.stderr, flush=True)


def _debug(msg: str) -> None:
    """Trace only when NIX_OPS_MCP_DEBUG=1; written to debug log file, never stderr."""
    if not _DEBUG:
        return
    path = _get_debug_log_path()
    if path:
        try:
            with path.open("a", encoding="utf-8") as f:
                f.write(f"[nix-ops-mcp] {msg}\n")
        except OSError:
            pass


def _utcnow() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _read_message() -> Optional[Dict[str, Any]]:
    """Read one JSON-RPC message from stdin.

    Supports Content-Length framing (MCP/LSP spec) and bare newline-delimited JSON.
    """
    while True:
        raw = sys.stdin.buffer.readline()
        if not raw:
            _debug("read_message: EOF")
            return None

        stripped = raw.strip()
        if not stripped:
            continue

        _debug(f"read_message: line ({len(raw)}B) {stripped[:120]!r}")

        # Content-Length header → LSP-style framed message
        if stripped.lower().startswith(b"content-length"):
            try:
                content_length = int(stripped.split(b":", 1)[1])
            except (ValueError, IndexError):
                _debug("read_message: bad Content-Length value, skipping")
                continue

            while True:
                hdr = sys.stdin.buffer.readline()
                if not hdr or hdr.strip() == b"":
                    break

            if content_length <= 0:
                _debug("read_message: content-length <= 0, skipping")
                continue

            body = sys.stdin.buffer.read(content_length)
            if len(body) < content_length:
                _debug(f"read_message: short body ({len(body)}/{content_length})")
                return None

            try:
                msg = json.loads(body)
                _debug(f"read_message: LSP-framed method={msg.get('method')}")
                return msg
            except (json.JSONDecodeError, UnicodeDecodeError) as exc:
                _debug(f"read_message: body parse error: {exc}")
                continue

        # Bare JSON object on a single line
        if stripped.startswith(b"{"):
            try:
                msg = json.loads(stripped)
                _debug(f"read_message: bare-JSON method={msg.get('method')}")
                return msg
            except (json.JSONDecodeError, UnicodeDecodeError) as exc:
                _debug(f"read_message: JSON parse error: {exc}")
                continue

        # Some other header line (e.g. Content-Type) before Content-Length
        _debug("read_message: unrecognized line, skipping")


def _write_message(payload: Dict[str, Any]) -> None:
    raw = json.dumps(payload, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    out = sys.stdout.buffer
    out.write(raw)
    out.write(b"\n")
    out.flush()


def _jsonrpc_result(request_id: Any, result: Any) -> Dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def _jsonrpc_error(request_id: Any, code: int, message: str, data: Any = None) -> Dict[str, Any]:
    error: Dict[str, Any] = {"code": code, "message": message}
    if data is not None:
        error["data"] = data
    return {"jsonrpc": "2.0", "id": request_id, "error": error}


_NOTIFICATION = object()


def _tool_result(payload: Dict[str, Any]) -> Dict[str, Any]:
    text = json.dumps(payload, indent=2, ensure_ascii=True)
    return {"content": [{"type": "text", "text": text}]}


def _load_config() -> Dict[str, Any]:
    config_path = Path(os.environ.get("NIX_OPS_MCP_CONFIG", DEFAULT_CONFIG))
    if not config_path.is_absolute():
        config_path = Path.cwd() / config_path
    _debug(f"load_config: path={config_path} exists={config_path.exists()}")
    if not config_path.exists():
        return {
            "repoRoot": str(Path.cwd()),
            "allowedHosts": {},
            "sshOptions": ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8"],
            "allowMutations": False,
            "approvalSalt": "",
            "uartCacheLog": DEFAULT_UART_CACHE_LOG,
        }
    with config_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    data.setdefault("repoRoot", str(Path.cwd()))
    data.setdefault("allowedHosts", {})
    data.setdefault("sshOptions", ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8"])
    data.setdefault("allowMutations", False)
    data.setdefault("approvalSalt", "")
    data.setdefault("uartCacheLog", DEFAULT_UART_CACHE_LOG)
    return data


def _append_audit(event: Dict[str, Any], config: Dict[str, Any]) -> None:
    log_path = Path(config.get("auditLog", DEFAULT_AUDIT_LOG))
    if not log_path.is_absolute():
        log_path = Path(config.get("repoRoot", Path.cwd())) / log_path
    log_path.parent.mkdir(parents=True, exist_ok=True)
    record = {
        "ts": _utcnow().isoformat(),
        **event,
    }
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=True) + "\n")


def _uart_cache_path(config: Dict[str, Any]) -> Path:
    cache_path = Path(config.get("uartCacheLog", DEFAULT_UART_CACHE_LOG))
    if not cache_path.is_absolute():
        cache_path = Path(config.get("repoRoot", Path.cwd())) / cache_path
    return cache_path


def _append_uart_cache_capture(
    *,
    device: str,
    baud_rate: int,
    seconds: int,
    max_bytes: int,
    bytes_read: int,
    stdout_text: str,
    config: Dict[str, Any],
) -> int:
    cache_path = _uart_cache_path(config)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    capture_ts = _utcnow().isoformat()

    lines = stdout_text.splitlines()
    records: List[Dict[str, Any]] = []
    if lines:
        for line in lines:
            records.append(
                {
                    "ts": capture_ts,
                    "device": device,
                    "baudRate": baud_rate,
                    "seconds": seconds,
                    "maxBytes": max_bytes,
                    "bytesRead": bytes_read,
                    "line": line,
                }
            )
    else:
        records.append(
            {
                "ts": capture_ts,
                "device": device,
                "baudRate": baud_rate,
                "seconds": seconds,
                "maxBytes": max_bytes,
                "bytesRead": bytes_read,
                "line": "",
                "emptyCapture": True,
            }
        )

    with cache_path.open("a", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=True) + "\n")

    return len(records)


def _read_uart_cache_entries(config: Dict[str, Any]) -> List[Dict[str, Any]]:
    cache_path = _uart_cache_path(config)
    if not cache_path.exists():
        return []
    entries: List[Dict[str, Any]] = []
    with cache_path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            try:
                parsed = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(parsed, dict):
                entries.append(parsed)
    return entries


def _run_command(
    cmd: List[str],
    *,
    cwd: str,
    timeout: int = 300,
    env: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
    start = _utcnow()
    proc = subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    end = _utcnow()
    return {
        "command": cmd,
        "cwd": cwd,
        "exitCode": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "startedAt": start.isoformat(),
        "finishedAt": end.isoformat(),
        "durationSeconds": round((end - start).total_seconds(), 3),
    }


ERROR_PATTERN = re.compile(r"error:\s*(.+)")
PATH_PATTERN = re.compile(r"(/[^:\s]+\.nix):(\d+):(\d+)")


def _extract_diagnostics(output: str) -> List[Dict[str, Any]]:
    diagnostics: List[Dict[str, Any]] = []
    lines = output.splitlines()
    for idx, line in enumerate(lines):
        error_match = ERROR_PATTERN.search(line)
        if not error_match:
            continue
        message = error_match.group(1).strip()
        location: Optional[Dict[str, Any]] = None
        for j in range(idx, min(idx + 8, len(lines))):
            loc_match = PATH_PATTERN.search(lines[j])
            if loc_match:
                location = {
                    "file": loc_match.group(1),
                    "line": int(loc_match.group(2)),
                    "column": int(loc_match.group(3)),
                }
                break
        item: Dict[str, Any] = {"message": message}
        if location:
            item["location"] = location
        diagnostics.append(item)
    return diagnostics


def _host_target(host: str, config: Dict[str, Any]) -> str:
    allowed_hosts = config.get("allowedHosts", {})
    host_entry = allowed_hosts.get(host)
    if not host_entry:
        raise ValueError(f"Host '{host}' is not present in allowedHosts")
    target = host_entry.get("sshTarget")
    if not target:
        raise ValueError(f"Host '{host}' is missing sshTarget")
    return str(target)


def _run_ssh(host: str, remote_cmd: str, config: Dict[str, Any], timeout: int = 60) -> Dict[str, Any]:
    target = _host_target(host, config)
    ssh_options = [str(item) for item in config.get("sshOptions", [])]
    cmd = ["ssh", *ssh_options, target, remote_cmd]
    result = _run_command(cmd, cwd=config["repoRoot"], timeout=timeout)
    result["host"] = host
    result["sshTarget"] = target
    return result


_UART_BAUD_MAP = {
    9600: termios.B9600,
    19200: termios.B19200,
    38400: termios.B38400,
    57600: termios.B57600,
    115200: termios.B115200,
}


def _discover_uart_ttys() -> List[str]:
    devices: List[str] = []
    for pattern in ("/dev/ttyACM*", "/dev/ttyUSB*"):
        devices.extend(glob.glob(pattern))
    return sorted(set(devices))


def _capture_uart(
    device: str,
    *,
    baud_rate: int = 115200,
    seconds: int = 15,
    max_bytes: int = 16384,
    send_data: Optional[str] = None,
) -> Dict[str, Any]:
    if baud_rate not in _UART_BAUD_MAP:
        raise ValueError(f"Unsupported baudRate {baud_rate}. Supported: {sorted(_UART_BAUD_MAP)}")
    if seconds < 1 or seconds > 120:
        raise ValueError("seconds must be between 1 and 120")
    if max_bytes < 256 or max_bytes > 262144:
        raise ValueError("maxBytes must be between 256 and 262144")

    fd: Optional[int] = None
    original_attr: Optional[List[Any]] = None
    chunks: List[bytes] = []
    total = 0
    deadline = _utcnow() + dt.timedelta(seconds=seconds)

    try:
        fd = os.open(device, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        original_attr = termios.tcgetattr(fd)
        attrs = termios.tcgetattr(fd)

        attrs[0] = termios.IGNPAR
        attrs[1] = 0
        attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        attrs[3] = 0
        attrs[6][termios.VMIN] = 0
        attrs[6][termios.VTIME] = 1
        attrs[4] = _UART_BAUD_MAP[baud_rate]
        attrs[5] = _UART_BAUD_MAP[baud_rate]
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        termios.tcflush(fd, termios.TCIFLUSH)

        if send_data:
            os.write(fd, send_data.encode("utf-8", errors="ignore"))

        while _utcnow() < deadline and total < max_bytes:
            remaining = (deadline - _utcnow()).total_seconds()
            timeout = 0.2 if remaining > 0.2 else max(remaining, 0.0)
            readable, _, _ = select.select([fd], [], [], timeout)
            if not readable:
                continue
            read_len = min(4096, max_bytes - total)
            if read_len <= 0:
                break
            try:
                data = os.read(fd, read_len)
            except BlockingIOError:
                continue
            if not data:
                continue
            chunks.append(data)
            total += len(data)

        combined = b"".join(chunks)
        return {
            "device": device,
            "baudRate": baud_rate,
            "seconds": seconds,
            "maxBytes": max_bytes,
            "bytesRead": len(combined),
            "stdout": combined.decode("utf-8", errors="replace"),
            "hexPreview": combined[:256].hex(),
        }
    finally:
        if fd is not None and original_attr is not None:
            try:
                termios.tcsetattr(fd, termios.TCSANOW, original_attr)
            except Exception:
                pass
        if fd is not None:
            try:
                os.close(fd)
            except Exception:
                pass


class NixOpsServer:
    def __init__(self) -> None:
        _debug("NixOpsServer: loading config")
        self.config = _load_config()
        self.repo_root = self.config["repoRoot"]
        _debug(f"NixOpsServer: repo_root={self.repo_root}")
        self.tools = {
            "check_flake": self.check_flake,
            "list_hosts": self.list_hosts,
            "eval_host": self.eval_host,
            "build_host": self.build_host,
            "build_installer": self.build_installer,
            "format_check": self.format_check,
            "parse_nix_error": self.parse_nix_error,
            "pi_journal": self.pi_journal,
            "pi_dmesg": self.pi_dmesg,
            "pi_service_status": self.pi_service_status,
            "pi_firmware_check": self.pi_firmware_check,
            "pi_uart_console": self.pi_uart_console,
            "pi_uart_cache_query": self.pi_uart_cache_query,
            "pi_uart_cache_range": self.pi_uart_cache_range,
            "deploy_plan": self.deploy_plan,
            "deploy_execute": self.deploy_execute,
        }

    def list_tool_specs(self) -> List[Dict[str, Any]]:
        return [
            {
                "name": "check_flake",
                "description": "Run nix flake check with structured diagnostics.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "build": {"type": "boolean", "default": False},
                        "timeoutSeconds": {"type": "integer", "default": 600},
                    },
                },
            },
            {
                "name": "list_hosts",
                "description": "List hostnames from nixosConfigurations.",
                "inputSchema": {"type": "object", "properties": {}},
            },
            {
                "name": "eval_host",
                "description": "Evaluate host toplevel derivation path.",
                "inputSchema": {
                    "type": "object",
                    "required": ["hostname"],
                    "properties": {"hostname": {"type": "string"}},
                },
            },
            {
                "name": "build_host",
                "description": "Build host toplevel derivation (dry-run default).",
                "inputSchema": {
                    "type": "object",
                    "required": ["hostname"],
                    "properties": {
                        "hostname": {"type": "string"},
                        "dryRun": {"type": "boolean", "default": True},
                        "timeoutSeconds": {"type": "integer", "default": 3600},
                    },
                },
            },
            {
                "name": "build_installer",
                "description": "Build Pi installer image output for pix4 or pix5.",
                "inputSchema": {
                    "type": "object",
                    "required": ["variant"],
                    "properties": {
                        "variant": {"type": "string", "enum": ["pix4", "pix5"]},
                        "dryRun": {"type": "boolean", "default": True},
                        "timeoutSeconds": {"type": "integer", "default": 7200},
                    },
                },
            },
            {
                "name": "format_check",
                "description": "Run nixpkgs-fmt check across repository.",
                "inputSchema": {"type": "object", "properties": {}},
            },
            {
                "name": "parse_nix_error",
                "description": "Parse Nix stderr/stdout into diagnostics list.",
                "inputSchema": {
                    "type": "object",
                    "required": ["output"],
                    "properties": {"output": {"type": "string"}},
                },
            },
            {
                "name": "pi_journal",
                "description": "Read journal logs from an allowlisted Pi host.",
                "inputSchema": {
                    "type": "object",
                    "required": ["host"],
                    "properties": {
                        "host": {"type": "string"},
                        "unit": {"type": "string"},
                        "lines": {"type": "integer", "default": 200},
                        "since": {"type": "string"},
                    },
                },
            },
            {
                "name": "pi_dmesg",
                "description": "Read kernel ring buffer from an allowlisted Pi host.",
                "inputSchema": {
                    "type": "object",
                    "required": ["host"],
                    "properties": {
                        "host": {"type": "string"},
                        "lines": {"type": "integer", "default": 200},
                    },
                },
            },
            {
                "name": "pi_service_status",
                "description": "Read systemd service status from an allowlisted Pi host.",
                "inputSchema": {
                    "type": "object",
                    "required": ["host", "unit"],
                    "properties": {
                        "host": {"type": "string"},
                        "unit": {"type": "string"},
                    },
                },
            },
            {
                "name": "pi_firmware_check",
                "description": "Inspect firmware partition on an allowlisted Pi host: lists files, shows config.txt, detects boot mode (classic vs UEFI).",
                "inputSchema": {
                    "type": "object",
                    "required": ["host"],
                    "properties": {
                        "host": {"type": "string"},
                    },
                },
            },
            {
                "name": "pi_uart_console",
                "description": "Discover /dev/ttyACM* and /dev/ttyUSB* serial devices and capture UART output for Pi boot debugging.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "device": {"type": "string"},
                        "baudRate": {"type": "integer", "default": 115200},
                        "seconds": {"type": "integer", "default": 15},
                        "maxBytes": {"type": "integer", "default": 16384},
                        "send": {"type": "string"},
                    },
                },
            },
            {
                "name": "pi_uart_cache_query",
                "description": "Search cached UART lines using a regex pattern.",
                "inputSchema": {
                    "type": "object",
                    "required": ["pattern"],
                    "properties": {
                        "pattern": {"type": "string"},
                        "ignoreCase": {"type": "boolean", "default": False},
                        "maxLines": {"type": "integer", "default": 200},
                        "device": {"type": "string"},
                    },
                },
            },
            {
                "name": "pi_uart_cache_range",
                "description": "Return cached UART lines for an inclusive line-number range.",
                "inputSchema": {
                    "type": "object",
                    "required": ["startLine", "endLine"],
                    "properties": {
                        "startLine": {"type": "integer"},
                        "endLine": {"type": "integer"},
                    },
                },
            },
            {
                "name": "deploy_plan",
                "description": "Produce a deploy command plan without executing.",
                "inputSchema": {
                    "type": "object",
                    "required": ["host"],
                    "properties": {
                        "host": {"type": "string"},
                        "mode": {"type": "string", "enum": ["test", "switch", "boot"], "default": "test"},
                    },
                },
            },
            {
                "name": "deploy_execute",
                "description": "Execute guarded deploy command with explicit confirmation.",
                "inputSchema": {
                    "type": "object",
                    "required": ["host", "confirmation"],
                    "properties": {
                        "host": {"type": "string"},
                        "mode": {"type": "string", "enum": ["test", "switch", "boot"], "default": "test"},
                        "confirmation": {"type": "string"},
                        "timeoutSeconds": {"type": "integer", "default": 1800},
                    },
                },
            },
        ]

    def check_flake(self, args: Dict[str, Any]) -> Dict[str, Any]:
        build = bool(args.get("build", False))
        timeout = int(args.get("timeoutSeconds", 600))
        cmd = ["nix", "flake", "check"]
        if not build:
            cmd.append("--no-build")
        result = _run_command(cmd, cwd=self.repo_root, timeout=timeout)
        diagnostics = _extract_diagnostics(result["stderr"] + "\n" + result["stdout"])
        result["diagnostics"] = diagnostics
        return result

    def list_hosts(self, _args: Dict[str, Any]) -> Dict[str, Any]:
        cmd = ["nix", "eval", "--json", ".#nixosConfigurations", "--apply", "builtins.attrNames"]
        result = _run_command(cmd, cwd=self.repo_root, timeout=120)
        hosts: List[str] = []
        if result["exitCode"] == 0:
            try:
                hosts = json.loads(result["stdout"])
            except json.JSONDecodeError:
                hosts = []
        return {"result": result, "hosts": hosts}

    def eval_host(self, args: Dict[str, Any]) -> Dict[str, Any]:
        host = str(args["hostname"])
        attr = f".#nixosConfigurations.{host}.config.system.build.toplevel.drvPath"
        cmd = ["nix", "eval", "--raw", attr]
        result = _run_command(cmd, cwd=self.repo_root, timeout=240)
        result["hostname"] = host
        return result

    def build_host(self, args: Dict[str, Any]) -> Dict[str, Any]:
        host = str(args["hostname"])
        dry_run = bool(args.get("dryRun", True))
        timeout = int(args.get("timeoutSeconds", 3600))
        attr = f".#nixosConfigurations.{host}.config.system.build.toplevel"
        cmd = ["nix", "build", attr]
        if dry_run:
            cmd.append("--dry-run")
        result = _run_command(cmd, cwd=self.repo_root, timeout=timeout)
        result["hostname"] = host
        result["dryRun"] = dry_run
        result["diagnostics"] = _extract_diagnostics(result["stderr"])
        return result

    def build_installer(self, args: Dict[str, Any]) -> Dict[str, Any]:
        variant = str(args["variant"])
        dry_run = bool(args.get("dryRun", True))
        timeout = int(args.get("timeoutSeconds", 7200))
        attr_map = {
            "pix4": ".#packages.aarch64-linux.createInstallSD-pix4",
            "pix5": ".#packages.aarch64-linux.createInstallSD-pix5",
        }
        cmd = ["nix", "build", attr_map[variant]]
        if dry_run:
            cmd.append("--dry-run")
        result = _run_command(cmd, cwd=self.repo_root, timeout=timeout)
        result["variant"] = variant
        result["dryRun"] = dry_run
        result["diagnostics"] = _extract_diagnostics(result["stderr"])
        return result

    def format_check(self, _args: Dict[str, Any]) -> Dict[str, Any]:
        cmd = ["nix", "run", "nixpkgs#nixpkgs-fmt", "--", "--check", "."]
        result = _run_command(cmd, cwd=self.repo_root, timeout=240)
        return result

    def parse_nix_error(self, args: Dict[str, Any]) -> Dict[str, Any]:
        output = str(args["output"])
        return {"diagnostics": _extract_diagnostics(output)}

    def pi_journal(self, args: Dict[str, Any]) -> Dict[str, Any]:
        host = str(args["host"])
        lines = int(args.get("lines", 200))
        unit = args.get("unit")
        since = args.get("since")
        cmd_parts = ["journalctl", "--no-pager", "-n", str(lines)]
        if unit:
            cmd_parts += ["-u", str(unit)]
        if since:
            cmd_parts += ["--since", str(since)]
        remote_cmd = " ".join(cmd_parts)
        result = _run_ssh(host, remote_cmd, self.config, timeout=90)
        _append_audit({"tool": "pi_journal", "host": host, "unit": unit}, self.config)
        return result

    def pi_dmesg(self, args: Dict[str, Any]) -> Dict[str, Any]:
        host = str(args["host"])
        lines = int(args.get("lines", 200))
        remote_cmd = f"dmesg --color=never | tail -n {lines}"
        result = _run_ssh(host, remote_cmd, self.config, timeout=90)
        _append_audit({"tool": "pi_dmesg", "host": host, "lines": lines}, self.config)
        return result

    def pi_service_status(self, args: Dict[str, Any]) -> Dict[str, Any]:
        host = str(args["host"])
        unit = str(args["unit"])
        remote_cmd = f"systemctl status {unit} --no-pager -l"
        result = _run_ssh(host, remote_cmd, self.config, timeout=90)
        _append_audit({"tool": "pi_service_status", "host": host, "unit": unit}, self.config)
        return result

    def pi_firmware_check(self, args: Dict[str, Any]) -> Dict[str, Any]:
        host = str(args["host"])
        script = (
            "echo '=== FIRMWARE FILES ===' && "
            "ls -lhA /boot/firmware/ 2>/dev/null || echo '/boot/firmware not mounted' && "
            "echo && echo '=== OVERLAYS ===' && "
            "ls /boot/firmware/overlays/ 2>/dev/null | head -20 || echo 'no overlays dir' && "
            "echo && echo '=== CONFIG.TXT ===' && "
            "cat /boot/firmware/config.txt 2>/dev/null || echo 'no config.txt' && "
            "echo && echo '=== BOOT MODE ===' && "
            "if [ -f /boot/firmware/RPI_EFI.fd ]; then echo 'UEFI firmware present'; "
            "else echo 'No UEFI firmware (classic boot)'; fi && "
            "echo && echo '=== ESP FILES ===' && "
            "ls -lhA /boot/ 2>/dev/null | head -20 || echo '/boot not mounted' && "
            "echo && echo '=== BOOTCTL ===' && "
            "bootctl status --no-pager 2>/dev/null || echo 'bootctl not available or not UEFI boot'"
        )
        result = _run_ssh(host, script, self.config, timeout=30)
        _append_audit({"tool": "pi_firmware_check", "host": host}, self.config)

        summary: Dict[str, Any] = {"host": host}
        stdout = result.get("stdout", "")
        summary["hasUefiFirmware"] = "UEFI firmware present" in stdout
        summary["hasConfigTxt"] = "no config.txt" not in stdout
        if "kernel=RPI_EFI.fd" in stdout:
            summary["bootMode"] = "uefi"
        elif "kernel=kernel.img" in stdout:
            summary["bootMode"] = "classic-kernel"
        else:
            summary["bootMode"] = "unknown"

        result["summary"] = summary
        return result

    def pi_uart_console(self, args: Dict[str, Any]) -> Dict[str, Any]:
        discovered = _discover_uart_ttys()
        if not discovered:
            return {
                "error": "No matching UART devices found.",
                "searchedPatterns": ["/dev/ttyACM*", "/dev/ttyUSB*"],
                "discovered": [],
            }

        requested = args.get("device")
        if requested:
            device = str(requested)
            if device not in discovered:
                return {
                    "error": "Requested device not found in discovered UART devices.",
                    "requestedDevice": device,
                    "discovered": discovered,
                }
        else:
            device = discovered[0]

        baud_rate = int(args.get("baudRate", 115200))
        seconds = int(args.get("seconds", 15))
        max_bytes = int(args.get("maxBytes", 16384))
        send_data = args.get("send")
        if send_data is not None:
            send_data = str(send_data)

        result = _capture_uart(
            device,
            baud_rate=baud_rate,
            seconds=seconds,
            max_bytes=max_bytes,
            send_data=send_data,
        )
        result["discovered"] = discovered
        cached_lines = _append_uart_cache_capture(
            device=device,
            baud_rate=baud_rate,
            seconds=seconds,
            max_bytes=max_bytes,
            bytes_read=int(result.get("bytesRead", 0)),
            stdout_text=str(result.get("stdout", "")),
            config=self.config,
        )
        result["cachedLines"] = cached_lines
        result["uartCachePath"] = str(_uart_cache_path(self.config))
        _append_audit(
            {
                "tool": "pi_uart_console",
                "device": device,
                "baudRate": baud_rate,
                "seconds": seconds,
                "bytesRead": result.get("bytesRead"),
            },
            self.config,
        )
        return result

    def pi_uart_cache_query(self, args: Dict[str, Any]) -> Dict[str, Any]:
        pattern = str(args["pattern"])
        ignore_case = bool(args.get("ignoreCase", False))
        max_lines = int(args.get("maxLines", 200))
        if max_lines < 1 or max_lines > 2000:
            raise ValueError("maxLines must be between 1 and 2000")
        device = args.get("device")
        device_filter = str(device) if device is not None else None

        flags = re.IGNORECASE if ignore_case else 0
        try:
            matcher = re.compile(pattern, flags)
        except re.error as exc:
            raise ValueError(f"Invalid regex pattern: {exc}") from exc

        entries = _read_uart_cache_entries(self.config)
        matches: List[Dict[str, Any]] = []
        for idx, entry in enumerate(entries, start=1):
            line = str(entry.get("line", ""))
            entry_device = str(entry.get("device", ""))
            if device_filter and entry_device != device_filter:
                continue
            if matcher.search(line):
                matches.append(
                    {
                        "lineNumber": idx,
                        "ts": entry.get("ts"),
                        "device": entry_device,
                        "baudRate": entry.get("baudRate"),
                        "line": line,
                    }
                )
                if len(matches) >= max_lines:
                    break

        return {
            "cachePath": str(_uart_cache_path(self.config)),
            "pattern": pattern,
            "ignoreCase": ignore_case,
            "device": device_filter,
            "totalCacheLines": len(entries),
            "matchesReturned": len(matches),
            "matches": matches,
        }

    def pi_uart_cache_range(self, args: Dict[str, Any]) -> Dict[str, Any]:
        start_line = int(args["startLine"])
        end_line = int(args["endLine"])
        if start_line < 1:
            raise ValueError("startLine must be >= 1")
        if end_line < start_line:
            raise ValueError("endLine must be >= startLine")
        if end_line - start_line > 5000:
            raise ValueError("Requested range is too large (max 5000 lines)")

        entries = _read_uart_cache_entries(self.config)
        total = len(entries)
        if total == 0:
            return {
                "cachePath": str(_uart_cache_path(self.config)),
                "totalCacheLines": 0,
                "lines": [],
            }

        start_idx = min(start_line, total)
        end_idx = min(end_line, total)
        sliced = entries[start_idx - 1 : end_idx]
        lines: List[Dict[str, Any]] = []
        for idx, entry in enumerate(sliced, start=start_idx):
            lines.append(
                {
                    "lineNumber": idx,
                    "ts": entry.get("ts"),
                    "device": entry.get("device"),
                    "baudRate": entry.get("baudRate"),
                    "line": entry.get("line", ""),
                }
            )

        return {
            "cachePath": str(_uart_cache_path(self.config)),
            "requestedStartLine": start_line,
            "requestedEndLine": end_line,
            "returnedStartLine": start_idx,
            "returnedEndLine": end_idx,
            "totalCacheLines": total,
            "lines": lines,
        }

    def _deploy_command(self, host: str, mode: str) -> Tuple[List[str], str]:
        target = _host_target(host, self.config)
        cmd = [
            "nixos-rebuild",
            mode,
            "--flake",
            f".#{host}",
            "--target-host",
            target,
            "--use-remote-sudo",
        ]
        confirmation = f"deploy:{host}:{mode}:{self.config.get('approvalSalt', '')}"
        return cmd, confirmation

    def deploy_plan(self, args: Dict[str, Any]) -> Dict[str, Any]:
        host = str(args["host"])
        mode = str(args.get("mode", "test"))
        if mode not in {"test", "switch", "boot"}:
            raise ValueError("mode must be one of: test, switch, boot")
        cmd, confirmation = self._deploy_command(host, mode)
        return {
            "host": host,
            "mode": mode,
            "command": cmd,
            "requiresConfirmation": True,
            "confirmationToken": confirmation,
            "allowMutations": bool(self.config.get("allowMutations", False)),
        }

    def deploy_execute(self, args: Dict[str, Any]) -> Dict[str, Any]:
        host = str(args["host"])
        mode = str(args.get("mode", "test"))
        confirmation = str(args["confirmation"])
        timeout = int(args.get("timeoutSeconds", 1800))
        cmd, expected = self._deploy_command(host, mode)

        if mode in {"switch", "boot"} and not bool(self.config.get("allowMutations", False)):
            return {
                "error": "Mutation blocked by config. Set allowMutations=true explicitly.",
                "expectedConfirmationToken": expected,
            }
        if confirmation != expected:
            return {
                "error": "Confirmation token mismatch.",
                "expectedConfirmationToken": expected,
            }
        result = _run_command(cmd, cwd=self.repo_root, timeout=timeout)
        _append_audit({"tool": "deploy_execute", "host": host, "mode": mode, "exitCode": result["exitCode"]}, self.config)
        result["host"] = host
        result["mode"] = mode
        result["mutationAllowed"] = bool(self.config.get("allowMutations", False))
        result["diagnostics"] = _extract_diagnostics(result["stderr"])
        return result

    def call_tool(self, name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        handler = self.tools.get(name)
        if handler is None:
            raise ValueError(f"Unknown tool: {name}")
        return handler(arguments)


def _handle_request(server: NixOpsServer, request: Dict[str, Any]) -> Any:
    method = request.get("method")
    request_id = request.get("id")
    params = request.get("params", {})
    _debug(f"handle_request: method={method} id={request_id}")

    if method == "initialize":
        result = {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "nix-ops-mcp", "version": "0.2.0"},
        }
        return _jsonrpc_result(request_id, result)

    if method and method.startswith("notifications/"):
        return _NOTIFICATION

    if method == "tools/list":
        return _jsonrpc_result(request_id, {"tools": server.list_tool_specs()})
    if method == "tools/call":
        try:
            name = params.get("name", "")
            arguments = params.get("arguments", {}) or {}
            payload = server.call_tool(name, arguments)
            return _jsonrpc_result(request_id, _tool_result(payload))
        except Exception as exc:
            return _jsonrpc_error(request_id, -32000, str(exc))
    if method == "ping":
        return _jsonrpc_result(request_id, {"ok": True})
    return _jsonrpc_error(request_id, -32601, f"Method not found: {method}")


def main() -> int:
    _log("process started (set NIX_OPS_MCP_DEBUG=1 for trace)")
    _debug(f"main: cwd={os.getcwd()}")
    _debug("main: creating server")
    server = NixOpsServer()
    _debug("main: entering request loop")
    while True:
        _debug("main: waiting for message")
        request = _read_message()
        if request is None:
            _debug("main: no message, exiting")
            break
        _debug(f"main: got method={request.get('method')}")
        response = _handle_request(server, request)
        if response is _NOTIFICATION:
            continue
        if response:
            _debug("main: writing response")
            _write_message(response)
            _debug("main: response sent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Unified NixOS configuration managing a fleet of x86_64 PCs and aarch64 Raspberry Pi nodes. Secrets live in a separate `nix-secrets` repo.

## Common Commands

```bash
# Preflight (after more changes run)
nix flake check --no-build
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath

# Format
nix develop --command nixpkgs-fmt .

# Deploy to a host (prefer test first, then switch)
nixos-rebuild test  --flake .#<host> --target-host root@<ip>
nixos-rebuild switch --flake .#<host> --target-host root@<ip>

# Pi installer images (build on aarch64 to avoid cross-compilation)
nix build .#packages.aarch64-linux.createInstallSD-pix5

# Inspect Pi config.txt output
nix eval --raw .#nixosConfigurations.<host>.config.hardware.raspberry-pi.config-generated
```

## Architecture

### Host Builders

- **`mkHost`** — x86_64-linux PCs. Uses upstream `nixpkgs.lib.nixosSystem`. Hosts live in `hosts/nixos/<name>/`.
- **`mkPiHost`** — aarch64-linux Raspberry Pis. Uses `nixos-raspberrypi.lib.nixosSystemFull` (forked nixpkgs with Pi overlays). Hosts live in `hosts/pi/<name>/`. Pi builds **must** use `piLib`/`piCustomLib` (the fork's lib), not upstream lib.

### Host Specification (`hostSpec`)

Defined in `modules/common/host-spec.nix`. Every host sets `hostSpec` attributes (hostName, piModel, bootMedia, hasTpm, isServer, etc.) to drive conditional configuration. Modules read `config.hostSpec.*` to adapt behavior.

### Shared Configuration Layers

- `hosts/common/core/` — imported by all x86_64 hosts (ssh, sops, locale, nix settings, users)
- `hosts/pi/common.nix` — imported by all Pi hosts (equivalent core + Pi firmware config, initrd SSH, LUKS)

### Custom Library (`lib/default.nix`)

- `lib.custom.relativeToRoot` — path relative to repo root
- `lib.custom.scanPaths` — auto-import .nix files from a directory

### Key Flake Inputs

| Input | Purpose |
|-------|---------|
| `nixos-raspberrypi` | Forked nixpkgs for Pi (kernel, firmware, overlays) |
| `rpi5-uefi-nix` | Pi 5 UEFI firmware (EDK2) for measured boot |
| `disko` | Declarative disk partitioning |
| `sops-nix` | Secrets management (age-encrypted) |
| `home-manager` | Per-user configuration |
| `nix-secrets` | Private secrets repo (local path or SSH) |

### Pi Boot Chains

Two mutually exclusive boot paths:

**Classic** (`boot.loader.raspberry-pi.enable = true`):
`EEPROM → config.txt → kernel.img + initrd → NixOS`

**Measured/UEFI** (`piMeasuredBoot.enable = true`):
`EEPROM → config.txt → RPI_EFI.fd (EDK2) → systemd-boot → UKI → NixOS`

These cannot coexist — NixOS allows only one `system.build.installBootLoader`. The measured-boot module manages the FIRMWARE partition via activation scripts.

### Pi Two-Partition Layout

- **FIRMWARE** (`/boot/firmware`) — EEPROM-facing: config.txt, DTBs, overlays, RPI_EFI.fd or kernel.img
- **ESP** (`/boot`) — EFI System Partition: systemd-boot entries, kernel/initrd (UEFI path only)

### Pi Modules (`modules/hosts/nixos/pi/`)

- `measured-boot.nix` — UEFI + systemd-boot path, firmware sync activation script, diagnostic tools
- `tpm.nix` — TPM support and LUKS enrollment helpers
- `system-on-sd.nix` / `system-on-ssd.nix` — storage layout variants
- `home-media.nix` — media/retro console configuration

### Binary Cache

`space` (10.13.12.101:5000) serves as a local Nix binary cache for Pi hosts. Enabled when `hosts/pi/space-cache-public-key.txt` exists.

## Workflows

### Deploy Safety Protocol

1. `nix flake check --no-build`
2. Eval target host derivation path
3. Dry-run build
4. `nixos-rebuild test` first, then `switch` if successful
5. Post-deploy: `systemctl is-system-running`, `systemctl --failed`

### Incident Investigation

1. Gather evidence (journalctl, dmesg, systemctl status)
2. State 1-2 hypotheses
3. One minimal verification per hypothesis
4. Smallest safe config change
5. Re-check and summarize

### NixOS Module Development

1. Eval option definitions → 2. Check assertions → 3. Eval full host → 4. Dry-run build → 5. Inspect generated config → 6. Fix errors one at a time → 7. `nix flake check --no-build`

## Conventions

- Formatter: `nixpkgs-fmt`
- Pi hosts are `aarch64-linux` — avoid accidental x86→aarch64 cross-compilation; use native builders or remote builders
- Pi CI evaluation is not in GitHub Actions (no aarch64 runners); only x86 hosts are in the CI matrix
- Secrets: never print decrypted values, never commit plaintext keys. Sensitive paths: `../nix-secrets/sops/*.yaml`, `~/.config/sops/age/keys.txt`
- Use `lib.mkDefault` for overridable values, `lib.mkForce` sparingly with documentation
- Prefer `system.activationScripts` for filesystem setup over bootloader-install-time scripts

## Misc

- pix0's ip is 10.13.12.110 you can access it with ssh root@10.13.12.110
- if a problem is hard try to reduce the complexity by attempting one change at a time

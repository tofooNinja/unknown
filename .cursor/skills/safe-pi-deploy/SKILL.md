---
name: safe-pi-deploy
description: Executes guarded Pi deploy workflows with explicit preflight, confirmation, and post-checks. Use when deploying nixosConfigurations.pix* hosts or rolling out Pi installer changes.
---

# Safe Pi Deploy

## Preflight Checklist

- [ ] Confirm target host and deploy mode (`test`, `switch`, `boot`)
- [ ] `nix flake check --no-build`
- [ ] `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
- [ ] `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run`
- [ ] Confirm remote host reachability over SSH

## Execution Order

1. Prefer `nixos-rebuild test` first.
2. If successful and approved, proceed to `switch`.
3. Avoid `boot` unless required for known reason.

## Post-Deploy Validation

- `systemctl is-system-running`
- `systemctl --failed`
- service-specific smoke checks
- recent logs for touched units

## Rollback Guidance

If critical regressions appear, use previous generation rollback commands on target host and report exact failure window.

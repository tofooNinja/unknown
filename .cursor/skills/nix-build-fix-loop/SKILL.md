---
name: nix-build-fix-loop
description: Runs a reproducible build-fix loop for Nix flake and host errors. Use when a Nix evaluation or build command fails and the agent needs to patch and re-verify quickly.
---

# Nix Build Fix Loop

## Loop

1. Reproduce:
   - `nix flake check --no-build`
   - target eval/build commands if host-specific
2. Parse failure:
   - capture `error:` lines
   - identify first actionable file and symbol
3. Apply the smallest change that addresses the first failure.
4. Re-run the same command.
5. Repeat until clean or blocked by external dependency.

## Host-Specific Commands

- Eval: `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
- Build dry-run: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run`

## Guardrails

- Fix one root error at a time.
- Do not mix unrelated refactors into a fix pass.
- Keep output summary focused on what changed and what now passes.

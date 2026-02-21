# Skill: NixOS Module Development Loop

Iterative workflow for developing and testing NixOS modules in this flake.

## When to Use

- Creating or modifying NixOS modules under `modules/`
- Adding new options, assertions, or activation scripts
- Changing boot, firmware, or hardware configuration

## Workflow

### 1. Validate Option Definitions

Eval the module option tree to catch type errors and missing defaults:

```bash
nix eval --json .#nixosConfigurations.<host>.options.<module>.enable.type.description
```

### 2. Check Assertions

If the module has assertions, verify they fire correctly. Intentionally violate
a condition and confirm the build fails with the expected message:

```bash
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath 2>&1
```

### 3. Eval Full Host

Evaluate the target host to catch import cycles, infinite recursion, and
missing option values:

```bash
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
```

### 4. Dry-Run Build

Check that all derivations resolve without actually building:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run
```

### 5. Inspect Generated Config

For modules that generate config files (e.g., config.txt, activation scripts),
inspect the output directly:

```bash
# Pi config.txt
nix eval --raw .#nixosConfigurations.<host>.config.hardware.raspberry-pi.config-generated

# Activation scripts
nix eval --json .#nixosConfigurations.<host>.config.system.activationScripts | jq 'keys'

# Boot loader
nix eval --raw .#nixosConfigurations.<host>.config.system.build.installBootLoader
```

### 6. Iterate on Errors

When eval or build fails, use the `nix-build-fix-loop` skill:
1. Read the error message carefully
2. Fix one error at a time
3. Re-run eval
4. Repeat until clean

### 7. Flake Check

Run the full flake check once the host evaluates cleanly:

```bash
nix flake check --no-build
```

## Guardrails

- Never skip straight to deploy; always eval and dry-run first.
- For Pi modules (aarch64), eval on the build host may require `--system aarch64-linux`
  or a remote builder.
- Use `lib.mkDefault` for values that consuming modules may override.
- Use `lib.mkForce` sparingly and document why.
- Keep assertions focused: one condition per assertion with a clear message.
- Prefer `system.activationScripts` for filesystem setup that runs on every
  activation, not just bootloader install.

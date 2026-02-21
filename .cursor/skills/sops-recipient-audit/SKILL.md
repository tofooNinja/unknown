---
name: sops-recipient-audit
description: Audits SOPS recipient coverage for host and shared secrets without exposing plaintext values. Use when adding hosts, rotating host keys, or debugging decryption access issues.
---

# SOPS Recipient Audit

## Goal

Verify that each host has the right age recipients and that encrypted files can be decrypted by intended identities.

## Audit Steps

1. Check `.sops.yaml` contains expected host entries.
2. Confirm target host key derivation source (SSH host key -> `ssh-to-age`).
3. Run `sops updatekeys` in dry validation workflows where possible.
4. Ensure affected files include the new/rotated recipient set.
5. Report missing host mappings before any deploy.

## Constraints

- Never print decrypted secret values.
- Summarize only key presence, recipient IDs, and pass/fail outcomes.
- Flag changes that require coordinated host reinstall or key rotation.

---
name: nix-fleet-triage
description: Triages NixOS host incidents using a consistent evidence-first workflow. Use when diagnosing failed services, boot issues, or runtime regressions on pix or nixos hosts.
---

# Nix Fleet Triage

## Objective

Collect enough evidence to produce a likely root cause and the smallest safe next action.

## Workflow

1. Confirm target host and symptom.
2. Collect evidence in this order:
   - `systemctl status <unit> --no-pager -l`
   - `journalctl -u <unit> --no-pager -n 200`
   - `dmesg --color=never | tail -n 200` for kernel/hardware issues
3. Summarize 1-2 hypotheses tied to evidence lines.
4. Run one verification command per hypothesis.
5. Propose a minimal fix and validation command.

## Output Template

```markdown
## Incident Summary
- Host:
- Service:
- Impact:

## Evidence
- ...

## Hypotheses
- H1:
- H2:

## Verification
- Command:
- Result:

## Recommended Next Step
- ...
```

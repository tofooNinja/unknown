# Branch Protection Setup

This document explains how to configure branch protection to require CI checks to pass before merging pull requests.

## Overview

Branch protection rules ensure that all CI checks must succeed before code can be merged into protected branches (main). This helps maintain code quality and prevents broken code from being merged.

## Required CI Checks

The following CI checks must pass before merging:

- **Nix Flake Check** - Validates flake structure and dependencies
- **Evaluate NixOS Configurations (space)** - Ensures space configuration evaluates
- **Evaluate NixOS Configurations (black)** - Ensures black configuration evaluates
- **Evaluate NixOS Configurations (metal-nvidia)** - Ensures metal-nvidia configuration evaluates
- **Evaluate NixOS Configurations (metal-wayland)** - Ensures metal-wayland configuration evaluates
- **Evaluate NixOS Configurations (deck)** - Ensures deck configuration evaluates
- **Check Formatting** - Verifies code is properly formatted with nixpkgs-fmt

## Secrets Required

The CI workflows need access to the private `unknown-secrets` repository. Add a deploy key:

1. Generate an SSH deploy key: `ssh-keygen -t ed25519 -f deploy_key -N ""`
2. Add the **public** key as a deploy key on the `unknown-secrets` repo (Settings → Deploy keys)
3. Add the **private** key as a secret named `NIX_SECRETS_DEPLOY_KEY` on this repo (Settings → Secrets)

## Setup Methods

### Method 1: Using GitHub UI (Recommended for Quick Setup)

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Branches**
3. Click **Add branch protection rule**
4. Configure the rule:
   - **Branch name pattern**: `main`
   - Check **Require status checks to pass before merging**
   - Check **Require branches to be up to date before merging**
   - Search and select the required status checks listed above
5. Click **Create** or **Save changes**

### Method 2: Using GitHub Settings App (Configuration as Code)

This repository includes a `.github/settings.yml` file that defines branch protection rules as code.

1. Install the [Settings GitHub App](https://github.com/apps/settings) on your repository
2. The app will automatically apply the configuration from `.github/settings.yml`
3. Any changes to `.github/settings.yml` will be applied automatically

### Method 3: Using GitHub CLI

```bash
gh api repos/tofooNinja/unknown/branches/main/protection \
  --method PUT \
  --field required_status_checks[strict]=true \
  --field 'required_status_checks[contexts][]=Nix Flake Check' \
  --field 'required_status_checks[contexts][]=Evaluate NixOS Configurations (space)' \
  --field 'required_status_checks[contexts][]=Evaluate NixOS Configurations (black)' \
  --field 'required_status_checks[contexts][]=Evaluate NixOS Configurations (metal-nvidia)' \
  --field 'required_status_checks[contexts][]=Evaluate NixOS Configurations (metal-wayland)' \
  --field 'required_status_checks[contexts][]=Evaluate NixOS Configurations (deck)' \
  --field 'required_status_checks[contexts][]=Check Formatting' \
  --field enforce_admins=false \
  --field required_pull_request_reviews=null
```

## Note on Pi Hosts

The Raspberry Pi hosts (pix0–pix3) are **aarch64-linux** and use the `nixos-raspberrypi` fork. They are not included in the CI evaluation matrix because GitHub-hosted runners are x86_64-only. To evaluate Pi configurations in CI, you would need a self-hosted aarch64 runner or use QEMU emulation.

## References

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitHub Settings App](https://github.com/apps/settings)
- [GitHub API - Branch Protection](https://docs.github.com/en/rest/branches/branch-protection)

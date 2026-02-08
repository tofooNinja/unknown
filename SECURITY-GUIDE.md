# Security & Secrets Management Guide

This guide walks you through generating all keys and secrets for your unified NixOS configuration.

## Overview

- **sops-nix** encrypts secrets at rest using age keys
- **Age keys** are derived from SSH host keys (for hosts) and generated separately (for users)
- **YubiKeys** provide FIDO2 LUKS unlock, GPG git signing, and SSH authentication
- **TPM** provides automatic LUKS unlock on pix0
- A **master age key** serves as offline recovery/admin key

## Prerequisites

Enter the dev shell for all needed tools:

```bash
cd matrix/nix-config
nix develop
```

This provides: `sops`, `ssh-to-age`, `age`, `yubikey-manager`, `yubikey-personalization`

---

## Step 1: Generate Master Age Key

This key can decrypt ALL secrets. Store it securely offline (e.g., encrypted USB drive).

```bash
age-keygen -o master-age-key.txt
# Output: AGE-SECRET-KEY-1... (save this!)
# Public key: age1... (note this for .sops.yaml)
```

Copy the public key and update `matrix/nix-secrets/.sops.yaml`:
replace the `&tofoo_primary` placeholder with your actual public key.

---

## Step 2: Generate/Collect Host Age Keys

Each host derives its age key from its SSH host key. You need to either:
- **Existing hosts**: Extract from `/etc/ssh/ssh_host_ed25519_key.pub`
- **New hosts**: Generate after first install

For each existing host, run:

```bash
# On the host, or remotely:
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
# Output: age1... (public key for this host)
```

Update each `&hostname` entry in `matrix/nix-secrets/.sops.yaml` with the actual age public keys.

For hosts not yet installed, you'll update `.sops.yaml` after their first boot.

---

## Step 3: Generate User Password

```bash
# Generate a hashed password for the tofoo user
mkpasswd -m sha-512
# Enter your desired password when prompted
# Output: $6$... (copy this hash)
```

Edit `matrix/nix-secrets/sops/shared.yaml` and replace the password placeholder.

---

## Step 4: Generate User Age Key

This key is used by home-manager to decrypt user-level secrets.

```bash
age-keygen -o user-age-key.txt
# Save the private key - it goes into shared.yaml as keys/age
# The public key is not needed in .sops.yaml (it's bootstrapped from host secrets)
```

Put the private key content into `sops/shared.yaml` under `keys.age`.

---

## Step 5: Encrypt Secrets with SOPS

Once all age keys are in `.sops.yaml`:

```bash
cd matrix/nix-secrets

# Encrypt shared secrets
sops --encrypt --in-place sops/shared.yaml

# Create and encrypt per-host secrets (if needed)
sops sops/space.yaml   # Opens editor, save to encrypt
sops sops/black.yaml
# ... repeat for each host
```

To edit encrypted secrets later:

```bash
sops sops/shared.yaml  # Decrypts, opens editor, re-encrypts on save
```

---

## Step 6: YubiKey Setup for PCs

### 6a. FIDO2 LUKS Enrollment

After installing a PC with the disko disk layout, enroll your YubiKey for LUKS unlock:

```bash
# On the PC (as root):
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-disk0-luks \
  --fido2-device=auto \
  --fido2-with-client-pin=yes

# Test: reboot and touch YubiKey when prompted
```

The disko config already includes `fido2-device=auto` in crypttab, so the system
will automatically try the YubiKey before falling back to passphrase.

### 6b. GPG Keys for Git Signing

Generate GPG keys on YubiKey for git commit signing:

```bash
# Insert YubiKey
gpg --card-edit

# In the GPG card prompt:
admin
generate
# Follow prompts to generate keys on the card
# Choose key size 2048 or 4096
# Set expiry as desired

# After generation, note the key ID:
gpg --list-keys --keyid-format long

# Configure git to use this key:
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
```

### 6c. SSH Authentication via YubiKey

For SSH resident keys (works on any machine with the YubiKey):

```bash
# Generate a resident SSH key on YubiKey
ssh-keygen -t ed25519-sk -O resident -O application=ssh:tofoo

# Load from YubiKey on any machine:
ssh-add -K
```

Add the public key to `hosts/common/users/tofoo/keys/`.

---

## Step 7: TPM Enrollment for pix0

After installing pix0 with the encrypted disk:

```bash
# On pix0 (as root):
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-ssd-system \
  --tpm2-device=auto

# Optional: bind to specific PCRs (more secure but requires re-enrollment after kernel updates)
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-ssd-system \
  --tpm2-device=auto \
  --tpm2-pcrs=0+2+4+7

# Verify enrollment:
sudo cryptsetup luksDump /dev/disk/by-partlabel/disk-ssd-system | grep -A5 "Tokens:"

# Re-enrollment after kernel update:
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-partlabel/disk-ssd-system
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-ssd-system
```

---

## Step 8: Fallback & Recovery Keys

### Passphrase Fallback

All LUKS volumes have a passphrase in key slot 0. This always works as fallback
even if YubiKey or TPM fails. Store the passphrase securely.

### Recovery Age Key

If you lose access to all hosts, the master age key (Step 1) can decrypt
all secrets in the nix-secrets repo.

### YubiKey Residual Keys

The GPG subkeys and SSH resident keys on your YubiKeys work on any machine.
If you're on a different device:

```bash
# Load SSH key from YubiKey
ssh-add -K

# Import GPG key from YubiKey
gpg --card-status
# GPG will auto-fetch the public key if configured
```

---

## Quick Reference

| Secret Type | Where Stored | Encrypted By |
|---|---|---|
| User passwords | `sops/shared.yaml` | age (host + user keys) |
| User age key | `sops/shared.yaml` | age (host keys) |
| Host-specific secrets | `sops/<hostname>.yaml` | age (host + user keys) |
| LUKS passphrase | Your memory / offline | N/A |
| GPG keys | YubiKey hardware | YubiKey PIN |
| SSH resident keys | YubiKey hardware | YubiKey PIN |
| Master age key | Offline USB / safe | Your responsibility |

---

## Updating .sops.yaml After Adding a New Host

1. Install the host and boot it
2. Get the host's age public key: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
3. Add the key to `.sops.yaml` under `hosts`
4. Add a creation rule for the host's secrets file
5. Re-encrypt all secrets files that the host needs access to:
   ```bash
   sops updatekeys sops/shared.yaml
   sops updatekeys sops/<hostname>.yaml
   ```
6. Commit and push the nix-secrets repo

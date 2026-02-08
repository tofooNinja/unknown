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
# Public key: age1q3kzcm8gl43kq5e68e666su7e8cmva7fmlx79y6xgdc7je7zjgxqmcwtrx
```

Copy the public key and update `matrix/nix-secrets/.sops.yaml`:
replace the `&tofoo_primary` placeholder with your actual public key.

Install the private key so SOPS can decrypt secrets locally:

```bash
mkdir -p ~/.config/sops/age
cp master-age-key.txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
# Or if you want to use the SOPS_AGE_KEY_FILE env var instead:
export SOPS_AGE_KEY_FILE=/path/to/master-age-key.txt
```

_This is required before you can encrypt, decrypt, or edit any SOPS-managed files.
After setup, store `master-age-key.txt` securely offline (e.g., encrypted USB drive) and remove it from disk._

---

## Step 2: Generate, Replace, or Collect Host Age Keys

Each host's age key is derived from its SSH host key. You'll need to either create a new key, or replace an existing one if the host key has changed.

### For Existing Hosts (to collect or replace):

```bash
# On the host (or over SSH), extract the public host key and convert to age:
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
# Output: age1... (this is the host's age public key)
```

- **If replacing a key:** First, regenerate your SSH host keys (for example, ed25519 and RSA) with the following commands:

  ```bash
  # Generate new Ed25519 host key
  ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
  # Generate new RSA host key (optional, replace 4096 with desired bits)
  ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ''
  ```

  Then, extract and convert the new public host key to an age key as shown earlier:

  ```bash
  ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
  # ...or for RSA key:
  ssh-to-age < /etc/ssh/ssh_host_rsa_key.pub
  ```

  Use the output to replace the existing entry.
- Update the corresponding `&hostname` entry in `matrix/nix-secrets/.sops.yaml` with the age public key.

### For New Hosts (pre-generate before first deploy):

When deploying a new host with nixos-anywhere (see Step 6), you need the age key
_before_ install so sops can decrypt secrets on first boot. Pre-generate the SSH
host keys locally:

```bash
mkdir -p /tmp/<hostname>-keys/etc/ssh
ssh-keygen -t ed25519 -f /tmp/<hostname>-keys/etc/ssh/ssh_host_ed25519_key -N ''
ssh-keygen -t rsa -b 4096 -f /tmp/<hostname>-keys/etc/ssh/ssh_host_rsa_key -N ''

# Derive the age public key
ssh-to-age < /tmp/<hostname>-keys/etc/ssh/ssh_host_ed25519_key.pub
# Output: age1... (use this in .sops.yaml)
```

Update the `&hostname` entry in `.sops.yaml` with the age key and uncomment
`*hostname` in the relevant creation rules. Then re-encrypt:

```bash
cd matrix/nix-secrets
sops updatekeys sops/shared.yaml
sops updatekeys sops/<hostname>.yaml
```

**Store the private host key in sops** so it can be recovered or reused if the
host needs to be reinstalled with the same identity (avoids re-encrypting all
secrets):

```bash
sops sops/<hostname>.yaml
# Add:  ssh-host-ed25519-private: <paste contents of /tmp/<hostname>-keys/etc/ssh/ssh_host_ed25519_key>
# Save and exit
```

The pre-generated keys are shipped to the host during nixos-anywhere deployment
via `--extra-files` (see Step 6 for the full procedure).

_Note: After rotating or replacing host SSH keys, always update `.sops.yaml` with the **new** age public key, and re-encrypt affected secrets as needed._

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
# If the file already exists (even with just comments), encrypt it in-place first:
sops --encrypt --in-place sops/space.yaml

# If the file does NOT exist, sops will create it and open your editor:
# sops sops/space.yaml

# ... repeat for each host
```

To edit encrypted secrets later:

```bash
sops sops/shared.yaml  # Decrypts, opens editor, re-encrypts on save
```

---

## Step 6: Deploy a New PC with nixos-anywhere

This covers deploying a NixOS configuration to a new PC for the first time,
including disk formatting. nixos-anywhere handles everything remotely: it SSHes
into the target, kexec's into an installer, runs disko to format disks, installs
the configuration, and reboots.

**Prerequisite:** Complete Steps 1-5 first, including pre-generating the host's
SSH keys and updating `.sops.yaml` (see Step 2, "For New Hosts").

### 6a. Store Host Secrets in sops

Add the LUKS passphrase and SSH host key to the host's per-host secrets file so
they're encrypted and recoverable. If you followed Step 2, the SSH host key
should already be there.

```bash
cd matrix/nix-secrets
sops sops/<hostname>.yaml
# Add:
#   luks-passphrase: your-passphrase-here
#   ssh-host-ed25519-private: <contents of /tmp/<hostname>-keys/etc/ssh/ssh_host_ed25519_key>
# Save and exit - sops will encrypt it
```

Storing the SSH host key means you can reinstall the same host without
re-generating keys or re-encrypting all secrets -- just extract and reuse it.

### 6b. Boot the Target

**Option A (recommended):** Boot the target from a NixOS minimal installer USB.
Set a root password on the live installer:

```bash
sudo passwd root
```

Note the target's IP address: `ip a`

**Option B:** If the target is already running Linux with root SSH access,
nixos-anywhere can kexec into an installer from the running system.
**Warning: this will wipe the target disk.**

### 6c. Run nixos-anywhere

From the deploying machine (e.g., space):

```bash
cd matrix/nix-config

# Extract the LUKS passphrase from sops into a temp file for disko
sops -d --extract '["luks-passphrase"]' ../nix-secrets/sops/<hostname>.yaml > /tmp/disko-password

# Deploy
nix run github:nix-community/nixos-anywhere -- \
  --flake .#<hostname> \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  --extra-files /tmp/<hostname>-keys \
  root@<TARGET_IP>

nix run github:nix-community/nixos-anywhere -- \
  --flake .#black \
  --disk-encryption-keys /tmp/disko-password /tmp/disko-password \
  --extra-files /tmp/black-keys \
  root@10.13.12.209
```

What each flag does:

- `--flake .#<hostname>` — builds the host's NixOS configuration
- `--disk-encryption-keys /tmp/disko-password /tmp/disko-password` — copies
  the local passphrase file to `/tmp/disko-password` on the target for disko's
  LUKS encryption
- `--extra-files /tmp/<hostname>-keys` — installs the pre-generated SSH host
  keys (the directory mirrors `/`, so `etc/ssh/` lands at `/etc/ssh/`)

### 6d. Post-install

After the target reboots into the new system:

1. Verify you can log in (SSH or console with your sops-managed password)
2. Clean up temporary files on the deploying machine:
   ```bash
   rm /tmp/disko-password
   rm -rf /tmp/<hostname>-keys
   ```
3. Enroll YubiKey for FIDO2 LUKS unlock (see Step 7a below)

_Note: The build runs on the deploying machine and the closure is copied to the
target. Make sure the deploying machine has enough disk space and RAM. Also,
since `nix-secrets` is a flake input, commit your sops changes in the
nix-secrets repo before running nixos-anywhere._

---

## Step 7: YubiKey Setup for PCs

### 7a. FIDO2 LUKS Enrollment

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

### 7b. GPG Keys for Git Signing

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

### 7c. SSH Authentication via YubiKey

For SSH resident keys (works on any machine with the YubiKey):

```bash
# Generate a resident SSH key on YubiKey
ssh-keygen -t ed25519-sk -O resident -O application=ssh:tofoo

# Load from YubiKey on any machine:
ssh-add -K
```

Add the public key to `hosts/common/users/tofoo/keys/`.

---

## Step 8: TPM Enrollment for pix0

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

## Step 9: Fallback & Recovery Keys

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
| LUKS passphrase | `sops/<hostname>.yaml` | age (host + user keys) |
| SSH host key | `sops/<hostname>.yaml` | age (host + user keys) |
| GPG keys | YubiKey hardware | YubiKey PIN |
| SSH resident keys | YubiKey hardware | YubiKey PIN |
| Master age key | Offline USB / safe | Your responsibility |

---

## Updating .sops.yaml After Adding a New Host

### For first-time deployment (nixos-anywhere):

See Step 2 ("For New Hosts") and Step 6 for the full workflow.
Pre-generate SSH host keys, derive the age key, and update `.sops.yaml`
**before** deploying.

### For already-installed hosts:

1. Get the host's age public key: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
2. Add the key to `.sops.yaml` under `hosts`
3. Uncomment the host in the relevant creation rules
4. Re-encrypt all secrets files that the host needs access to:
   ```bash
   sops updatekeys sops/shared.yaml
   sops updatekeys sops/<hostname>.yaml
   ```
5. Commit and push the nix-secrets repo

# TPM & FIDO2 LUKS Runbook (pix0)

Quick reference for LUKS enrollment and recovery on pix0 (Pi 5, classic boot, TPM + FIDO2).

See [measured-boot-status.md](measured-boot-status.md) for why measured boot (PCR policy) is not yet viable.

## Current Boot Path

```
EEPROM → config.txt → kernel.img + initrd → systemd (initrd) → FIDO2/TPM LUKS unlock → NixOS
```

## LUKS Keyslots

| Slot | Type | Purpose |
|------|------|---------|
| 0 | Passphrase | Recovery fallback |
| 2 | TPM2 (no PCR) | Auto-unlock convenience |
| 3 | FIDO2 YubiKey | Touch-to-unlock (no PIN) |

## TPM Enrollment

```bash
# Enroll TPM without PCR policy (current recommended mode)
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-partlabel/disk-sd-system
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-sd-system

# If PCR-based enrollment becomes viable in the future:
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7+11 /dev/disk/by-partlabel/disk-sd-system
```

## FIDO2 Enrollment

```bash
# Enroll YubiKey (touch-only, no PIN, no user verification)
sudo systemd-cryptenroll \
  --fido2-device=auto \
  --fido2-with-client-pin=no \
  --fido2-with-user-presence=yes \
  --fido2-with-user-verification=no \
  /dev/disk/by-partlabel/disk-sd-system
```

## Verification

```bash
# Check token state
cryptsetup luksDump /dev/disk/by-partlabel/disk-sd-system | grep -A8 'Tokens:'

# Check TPM device
ls /dev/tpm*
tpm2_pcrread sha256:0,1,2,3,4,5,6,7,8,9,10,11
```

## Recovery

1. If FIDO2/TPM unlock fails at boot: enter passphrase at initrd prompt
2. If initrd prompt not visible on HDMI: SSH to initrd (port 42069)
3. Re-enroll tokens after recovery if needed

## Diagnostics

- UART: `/dev/ttyUSB1` at 115200 baud
- Journal: `journalctl -b`
- LUKS: `cryptsetup luksDump /dev/disk/by-partlabel/disk-sd-system`

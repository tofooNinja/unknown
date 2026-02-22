# Raspberry Pi 5 Measured Boot — Status & Findings

Last updated: 2026-02-22

## Current State

pix0 uses **classic boot** (EEPROM → config.txt → kernel.img) with:
- **TPM2** (Infineon SLB9670 via SPI) enrolled for LUKS unlock (no PCR policy)
- **FIDO2 YubiKey** enrolled for LUKS unlock (touch-only, no PIN)
- **Passphrase** as fallback recovery

Measured boot (PCR-bound TPM policy) is **not viable** with any available Pi 5 UEFI firmware as of February 2026.

## What We Tried

### UEFI Boot Chain (EDK2 + systemd-boot)

Successfully booted pix0 via:
```
EEPROM → config.txt (kernel=RPI_EFI.fd) → EDK2 (worproject v0.3) → systemd-boot → Linux
```

Key findings during the UEFI experiment:

1. **ElvishJerricco/rpi5-uefi-nix firmware hangs** after the UEFI banner. The worproject v0.3 prebuilt works.

2. **`armstub=` vs `kernel=` in config.txt**: Pi 5 EEPROM already includes BL31 (TF-A). Using `armstub=RPI_EFI.fd` starts EDK2 at the wrong exception level (EL3) causing an immediate hang. `kernel=RPI_EFI.fd` loads at EL2, which is correct.

3. **DTB passthrough is broken**: The worproject UEFI firmware does not forward the EEPROM-prepared device tree to Linux. Symptoms: `EFI stub: Generating empty DTB`. Fix: place a pre-merged DTB on the ESP and add `devicetree /dtbs/bcm2712-rpi-5-b.dtb` to systemd-boot entries.

4. **DTB overlays must be pre-merged**: Since UEFI doesn't forward the EEPROM DTB (which has overlays applied), overlays like `tpm-slb9670.dtbo` must be merged at build time using `fdtoverlay` and placed on the ESP.

5. **UART output stops after EFI stub**: The downstream RPi kernel UART driver fails to reinitialize after UEFI hands off control. No kernel serial output is available for debugging post-EFI-stub.

### TPM PCR Measurement — The Blocker

**All TPM PCRs read zero** with the worproject v0.3 firmware. Root cause:

- The RPi5 EDK2 platform **does not include Tcg2Pei or Tcg2Dxe modules**. These are the EDK2 SecurityPkg components responsible for discovering the TPM, extending PCRs during firmware execution, and producing the TCG event log.
- Without these modules compiled into the firmware binary, the UEFI firmware never communicates with the TPM at all.
- The proprietary Pi 5 EEPROM bootloader has no TPM awareness either.
- TF-A BL31 for Pi 5 is minimal and does not include measured boot extensions.

This means the entire measurement chain is broken from the start — systemd-boot and the kernel *could* extend PCRs 8-12, but without firmware initialization of the TPM event log, it's meaningless.

## Why U-Boot Doesn't Help (Yet)

U-Boot has working SPI TPM2 drivers and measured boot support on RPi4. However:

- On **RPi5/CM5**, the TPM is detected but PCRs remain zero ([RPi Forums, Oct 2025](https://forums.raspberrypi.com/viewtopic.php?t=389649))
- Likely cause: the RP1 southbridge chip's SPI controller has different timing/initialization than BCM2711, and the TPM misses its initialization window
- This is the same root issue as [raspberrypi/linux#6217](https://github.com/raspberrypi/linux/issues/6217) (IMA can't detect TPM due to deferred RP1 SPI clock init)

## Options for the Future

| Option | Effort | Outcome |
|--------|--------|---------|
| **Fork EDK2, add Tcg2 modules + RP1 SPI TPM driver** | Very high | True measured boot with systemd-boot chain |
| **Port U-Boot TPM measurement to Pi 5** | High (driver/timing work) | Measured boot via U-Boot, but lose systemd-boot |
| **Wait for upstream firmware support** | None | Unknown timeline; worproject repo is archived |
| **Use FIDO2 YubiKey** (current) | Done | Physical key = physical presence security |
| **PCR-less TPM** (current) | Done | Convenience auto-unlock, no anti-tamper |

## LUKS Keyslot Layout (pix0)

| Slot | Type | Notes |
|------|------|-------|
| 0 | Passphrase | Recovery fallback |
| 2 | TPM2 (no PCR policy) | Auto-unlock, no anti-tamper guarantee |
| 3 | FIDO2 YubiKey | Touch-only, no PIN (`fido2-with-client-pin=no`) |

## Module Reference

The UEFI measured boot module is preserved at `modules/hosts/nixos/pi/measured-boot.nix` but disabled on all hosts. To re-enable in the future:

```nix
piMeasuredBoot = {
  enable = true;
  dtbOverlays = [
    "${config.boot.loader.raspberry-pi.firmwarePackage}/share/raspberrypi/boot/overlays/tpm-slb9670.dtbo"
  ];
  # uefiFirmwareFd = <path-to-firmware-with-tcg2-support>;
};
```

Key requirements before re-enabling:
1. UEFI firmware with Tcg2Pei/Tcg2Dxe compiled in
2. Working SPI TPM driver in the firmware for RP1's SPI controller
3. Verify non-zero, stable PCRs across multiple cold boots
4. Enroll TPM with PCR policy gradually (start with PCR 11, then 7+11, then add 0/2/4)

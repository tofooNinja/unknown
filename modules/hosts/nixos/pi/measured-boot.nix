{ config
, lib
, pkgs
, rpi5-uefi-nix ? null
, ...
}:
let
  cfg = config.piMeasuredBoot;
  rpiFwPkg = config.boot.loader.raspberry-pi.firmwarePackage;
  fwSrc = "${rpiFwPkg}/share/raspberrypi/boot";
  configTxtPkg = config.boot.loader.raspberry-pi.configTxtPackage;
  firmwarePath = cfg.firmwarePath;
in
{
  options.piMeasuredBoot = {
    enable = lib.mkEnableOption "UEFI + UKI measured boot path for Raspberry Pi hosts";

    firmwarePath = lib.mkOption {
      type = lib.types.str;
      default = "/boot/firmware";
      description = "Mount point of the Pi FIRMWARE partition.";
    };

    uefiFirmwareFd = lib.mkOption {
      type = lib.types.path;
      default =
        if rpi5-uefi-nix != null
        then "${rpi5-uefi-nix.packages.${pkgs.stdenv.hostPlatform.system}.default}/FV/RPI_EFI.fd"
        else throw "piMeasuredBoot: provide rpi5-uefi-nix via specialArgs or set uefiFirmwareFd";
      description = "Path to the RPI_EFI.fd UEFI firmware binary.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.hostSpec.isPi;
        message = "piMeasuredBoot is only supported on Pi hosts.";
      }
      {
        assertion = config.hostSpec.piModel == "pi5";
        message = "piMeasuredBoot currently only supports Pi 5 (UEFI via EDK2).";
      }
    ];

    # ── Boot loader: systemd-boot on ESP, disable Pi bootloader ───
    boot.loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = false;
        efiSysMountPoint = "/boot";
      };
      raspberry-pi.enable = lib.mkForce false;
    };

    boot.initrd.systemd.enable = lib.mkDefault true;
    boot.uki.name = "nixos-${config.hostSpec.hostName}";

    # ── config.txt: UEFI armstub instead of direct kernel ─────────
    # The EEPROM loads RPI_EFI.fd as the ARM Trusted Firmware stub.
    # UEFI then discovers the ESP and runs systemd-boot.
    hardware.raspberry-pi.config.all.options = {
      armstub = {
        enable = true;
        value = "RPI_EFI.fd";
      };
      device_tree_address = {
        enable = true;
        value = "0x1f0000";
      };
      device_tree_end = {
        enable = true;
        value = "0x210000";
      };
      disable_commandline_tags = {
        enable = true;
        value = 2;
      };
    };

    # ── Firmware partition activation ─────────────────────────────
    # Syncs DTBs, overlays, UEFI firmware, and config.txt to the
    # FIRMWARE partition on every activation. systemd-boot manages
    # the ESP independently; this handles the EEPROM-facing side.
    system.activationScripts.pi-measured-boot-firmware = lib.stringAfter [ "specialfs" ] ''
      echo "[pi-measured-boot] syncing firmware partition at ${firmwarePath}"

      if ! mountpoint -q "${firmwarePath}"; then
        echo "[pi-measured-boot] WARNING: ${firmwarePath} is not mounted, attempting mount"
        mount "${firmwarePath}" || true
      fi

      if ! mountpoint -q "${firmwarePath}"; then
        echo "[pi-measured-boot] ERROR: ${firmwarePath} still not mounted, skipping firmware sync"
      else
        # DTBs
        for dtb in ${fwSrc}/*.dtb; do
          [ -f "$dtb" ] && cp -f "$dtb" "${firmwarePath}/$(basename "$dtb")"
        done

        # Overlays
        mkdir -p "${firmwarePath}/overlays"
        if [ -d "${fwSrc}/overlays" ]; then
          for ovr in ${fwSrc}/overlays/*; do
            [ -f "$ovr" ] && cp -f "$ovr" "${firmwarePath}/overlays/$(basename "$ovr")"
          done
        fi

        # UEFI firmware binary
        cp -f "${cfg.uefiFirmwareFd}" "${firmwarePath}/RPI_EFI.fd"

        # config.txt (generated from hardware.raspberry-pi.config)
        cp -f "${configTxtPkg}" "${firmwarePath}/config.txt"

        echo "[pi-measured-boot] firmware partition synced"
      fi
    '';

    # ── Diagnostic and management tools ───────────────────────────
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "pi-measured-boot-check" ''
        set -euo pipefail

        echo "== Boot mode =="
        if [ -f "${firmwarePath}/RPI_EFI.fd" ]; then
          echo "UEFI firmware present at ${firmwarePath}/RPI_EFI.fd"
        else
          echo "WARNING: no UEFI firmware on firmware partition"
        fi
        if bootctl is-installed 2>/dev/null; then
          echo "systemd-boot is installed on ESP"
        else
          echo "WARNING: systemd-boot not detected"
        fi
        echo

        echo "== systemd-analyze pcrs =="
        if ! systemd-analyze pcrs; then
          echo "systemd could not decode a full TPM event log on this boot path."
        fi
        echo

        echo "== TPM measure log =="
        if [ -f /run/log/systemd/tpm2-measure.log ]; then
          ls -l /run/log/systemd/tpm2-measure.log
          echo "measure log present"
        else
          echo "measure log missing"
        fi
        echo

        echo "== tpm2_pcrread sha256:0..11 =="
        pcr_output="$(tpm2_pcrread sha256:0,1,2,3,4,5,6,7,8,9,10,11)"
        echo "$pcr_output"
        echo

        all_zero_count="$(printf '%s\n' "$pcr_output" | ${pkgs.ripgrep}/bin/rg -c '0x0+$' || true)"
        if [ "''${all_zero_count:-0}" -ge 12 ]; then
          echo "All measured PCRs are zero — PCR-based LUKS policy is not enforceable."
          exit 2
        fi

        echo "At least one PCR is non-zero. PCR-bound enrollment is viable."
      '')

      (pkgs.writeShellScriptBin "pi-luks-tpm-reenroll" ''
        set -euo pipefail

        if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
          echo "Usage: pi-luks-tpm-reenroll <luks-device> [pcr-list]"
          echo "Example: pi-luks-tpm-reenroll /dev/disk/by-partlabel/disk-ssd-system 11"
          exit 1
        fi

        luks_device="$1"
        pcr_list="''${2:-}"

        echo "Wiping existing TPM2 token slot on $luks_device ..."
        systemd-cryptenroll --wipe-slot=tpm2 "$luks_device"

        if [ -n "$pcr_list" ]; then
          echo "Enrolling TPM2 token with PCR policy: $pcr_list"
          systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs="$pcr_list" "$luks_device"
        else
          echo "Enrolling TPM2 token without PCR policy (convenience mode)."
          systemd-cryptenroll --tpm2-device=auto "$luks_device"
        fi

        echo "Current token state:"
        cryptsetup luksDump "$luks_device" | ${pkgs.ripgrep}/bin/rg -n 'Tokens|tpm2|Keyslots' -A6
      '')

      (pkgs.writeShellScriptBin "pi-firmware-sync" ''
        set -euo pipefail
        echo "Re-running firmware partition sync..."
        /nix/var/nix/profiles/system/activate 2>&1 | grep '\[pi-measured-boot\]' || true
        echo "Verifying firmware partition:"
        ls -lh "${firmwarePath}/RPI_EFI.fd" 2>/dev/null || echo "RPI_EFI.fd missing!"
        ls -lh "${firmwarePath}/config.txt" 2>/dev/null || echo "config.txt missing!"
        echo "Current config.txt:"
        head -30 "${firmwarePath}/config.txt" 2>/dev/null || echo "cannot read config.txt"
      '')
    ];
  };
}

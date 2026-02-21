{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.piMeasuredBoot;
in
{
  options.piMeasuredBoot = {
    enable = lib.mkEnableOption "UEFI + UKI measured boot path for Raspberry Pi hosts";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.hostSpec.isPi;
        message = "piMeasuredBoot.enable is only supported on Pi hosts.";
      }
    ];

    # Measured boot requires a UEFI boot chain. Keep EFI variable writes disabled
    # since these devices typically do not expose writable EFI vars.
    boot.loader = {
      systemd-boot = {
        enable = true;
      };
      efi = {
        canTouchEfiVariables = false;
        efiSysMountPoint = "/boot";
      };
      raspberry-pi.enable = lib.mkForce false;
    };

    # Keep initrd systemd path active so TPM/unlock plumbing remains consistent
    # with current Pi config and can emit measured-boot metadata when available.
    boot.initrd.systemd.enable = lib.mkDefault true;

    # Keep UKI naming deterministic per host for easier troubleshooting.
    boot.uki.name = "nixos-${config.hostSpec.hostName}";

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "pi-measured-boot-check" ''
        #!/usr/bin/env bash
        set -euo pipefail

        echo "== systemd-analyze pcrs =="
        if ! systemd-analyze pcrs; then
          echo "systemd could not decode a full TPM event log on this boot path."
        fi
        echo

        echo "== systemd measure log =="
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
        if [ "$all_zero_count" -ge 12 ]; then
          echo "All measured PCRs are still zero. PCR-based LUKS policy is not enforceable on this boot."
          exit 2
        fi

        echo "At least one PCR is non-zero. You can test PCR-bound enrollment."
      '')

      (pkgs.writeShellScriptBin "pi-luks-tpm-reenroll" ''
        #!/usr/bin/env bash
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
    ];
  };
}

{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.piSecurity;
in
{
  options.piSecurity = {
    enable = lib.mkEnableOption "secure native Raspberry Pi boot defaults";

    useVendorFirmwareDeviceTree = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use DTBs/overlays from the Raspberry Pi firmware package instead of generation DTBs.";
    };

    tpmWithPin = {
      enable = lib.mkEnableOption "TPM2 + PIN unlock policy in initrd";

      pcrs = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional PCR profile passed to systemd-cryptenroll (example: 0+4+7).";
      };
    };

    canary = {
      enable = lib.mkEnableOption "initrd canary webhook ping before root unlock";

      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "HTTP/HTTPS endpoint to call from initrd. If empty, the notifier exits without sending.";
      };

      publicIpService = lib.mkOption {
        type = lib.types.str;
        default = "https://api.ipify.org";
        description = "Service used to resolve public IP for the canary message.";
      };

      ntfyServer = lib.mkOption {
        type = lib.types.str;
        default = "https://ntfy.sh";
        description = "Base URL of the ntfy server used for additional canary notifications.";
      };

      ntfyChannel = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional ntfy channel/topic to publish an additional canary message to.";
      };
    };

    otpSecureBoot = {
      enable = lib.mkEnableOption "RPi signed-boot workflow helpers (manual OTP burn)";

      firmwareMountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/boot/firmware";
      };

      bootBundlePath = lib.mkOption {
        type = lib.types.str;
        default = "/boot/boot.img";
      };

      bootSignaturePath = lib.mkOption {
        type = lib.types.str;
        default = "/boot/boot.sig";
      };
    };
  };

  config = lib.mkIf (cfg.enable && config.hostSpec.isPi) (lib.mkMerge [
    {
      boot.loader.raspberry-pi.bootloader = lib.mkDefault "kernel";

      boot.loader.raspberry-pi.useGenerationDeviceTree =
        lib.mkDefault (!cfg.useVendorFirmwareDeviceTree);

      hardware.raspberry-pi.config.all.options = {
        uart_2ndstage = {
          enable = true;
          value = true;
        };
        # Disables command line tags, preventing kernel command line arguments from being
        # processed or recognized during boot. This is a security measure that prevents
        # unauthorized modification of kernel boot parameters, which could be used to
        # bypass security restrictions or alter system behavior during the boot process.
        disable_commandline_tags = {
          enable = true;
          value = 2;
        };
      };
    }

    (lib.mkIf cfg.tpmWithPin.enable {
      assertions = [
        {
          assertion = config.hostSpec.hasTpm;
          message = "piSecurity.tpmWithPin.enable requires hostSpec.hasTpm = true";
        }
      ];

      piTpm.enable = lib.mkDefault true;

      boot.initrd.systemd.enable = lib.mkDefault true;
      boot.initrd.systemd.tpm2.enable = lib.mkForce false;
      boot.initrd.systemd.additionalUpstreamUnits = [
        "tpm2.target"
        "systemd-tpm2-setup-early.service"
      ];
      boot.initrd.systemd.storePaths = [
        pkgs.tpm2-tss
        "${config.boot.initrd.systemd.package}/lib/systemd/systemd-tpm2-setup"
        "${config.boot.initrd.systemd.package}/lib/systemd/system-generators/systemd-tpm2-generator"
      ];

      boot.initrd.luks.devices.crypted.crypttabExtraOpts = lib.mkAfter (
        [
          "tpm2-device=auto"
          "tpm2-pin=yes"
        ]
        ++ lib.optionals (cfg.tpmWithPin.pcrs != null) [ "tpm2-pcrs=${cfg.tpmWithPin.pcrs}" ]
      );

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "pi-luks-tpm-pin-enroll" ''
          set -euo pipefail

          if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
            echo "Usage: pi-luks-tpm-pin-enroll <luks-device> [pcrs]"
            echo "Example: pi-luks-tpm-pin-enroll /dev/disk/by-partlabel/disk-sd-system 0+4+7"
            exit 1
          fi

          luks_device="$1"
          pcrs="''${2:-}"

          ${pkgs.systemd}/bin/systemd-cryptenroll --wipe-slot=tpm2 "$luks_device"

          enroll_args=(--tpm2-device=auto --tpm2-with-pin=yes)
          if [ -n "$pcrs" ]; then
            enroll_args+=("--tpm2-pcrs=$pcrs")
          fi

          ${pkgs.systemd}/bin/systemd-cryptenroll "''${enroll_args[@]}" "$luks_device"
          echo "TPM2+PIN enrollment complete for $luks_device"
        '')
      ];
    })

    (lib.mkIf cfg.canary.enable {
      boot.initrd.systemd.storePaths = [
        pkgs.curl
        pkgs.cacert
        pkgs.iproute2
        pkgs.gnused
        pkgs.dnsutils
        pkgs.coreutils
      ];

      boot.initrd.systemd.services.pi-canary-notify = {
        description = "Initrd canary notification";
        wantedBy = [ "initrd.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        before = [ "cryptsetup.target" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig = {
          Type = "oneshot";
          TimeoutSec = 15;
        };
        script = ''
          set -eu

          endpoint='${cfg.canary.endpoint}'
          ca_bundle='${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt'
          public_ip="$(${pkgs.curl}/bin/curl --cacert "$ca_bundle" -fsS --max-time 5 '${cfg.canary.publicIpService}' || true)"
          local_ip="$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 2>/dev/null | ${pkgs.gnused}/bin/sed -n 's/.*src \([^ ]*\).*/\1/p' | ${pkgs.coreutils}/bin/head -n1 || true)"
          tofoo_ninja_ip="$(${pkgs.dnsutils}/bin/dig +short tofoo.ninja A | ${pkgs.coreutils}/bin/head -n1 || true)"

          ips_match=false
          if [ -n "$public_ip" ] && [ -n "$tofoo_ninja_ip" ] && [ "$public_ip" = "$tofoo_ninja_ip" ]; then
            ips_match=true
          fi

          if [ -n "$endpoint" ]; then
            ${pkgs.curl}/bin/curl -fsS --max-time 8 \
              --cacert "$ca_bundle" \
              --get \
              --data-urlencode "host=${config.hostSpec.hostName}" \
              --data-urlencode "phase=initrd" \
              --data-urlencode "public_ip=''${public_ip}" \
              --data-urlencode "local_ip=''${local_ip}" \
              --data-urlencode "tofoo.ninja_ip=''${tofoo_ninja_ip}" \
              --data-urlencode "ips_match=''${ips_match}" \
              "$endpoint" >/dev/null || true
          else
            echo "[pi-canary] endpoint is empty, skipping webhook"
          fi

          ntfy_channel='${cfg.canary.ntfyChannel}'
          if [ -n "$ntfy_channel" ]; then
            ${pkgs.curl}/bin/curl -fsS --max-time 8 \
              --cacert "$ca_bundle" \
              -H "Title: [canary] ${config.hostSpec.hostName} initrd" \
              -H "Tags: warning,lock" \
              -d "host=${config.hostSpec.hostName} phase=initrd public_ip=''${public_ip} local_ip=''${local_ip} tofoo.ninja_ip=''${tofoo_ninja_ip} ips_match=''${ips_match}" \
              "${cfg.canary.ntfyServer}/$ntfy_channel" >/dev/null || true
          fi
        '';
      };
    })

    (lib.mkIf cfg.otpSecureBoot.enable {
      environment.systemPackages = with pkgs; [
        raspberrypi-eeprom
        mtools
        dosfstools
        openssl
        (writeShellScriptBin "pi-secure-boot-status" ''
          set -euo pipefail

          echo "== Bootloader =="
          echo "boot.loader.raspberry-pi.bootloader = ${config.boot.loader.raspberry-pi.bootloader}"
          echo "firmware path: ${config.boot.loader.raspberry-pi.firmwarePath}"
          echo

          echo "== EEPROM config =="
          if command -v rpi-eeprom-config >/dev/null 2>&1; then
            rpi-eeprom-config 2>/dev/null | grep -E 'SIGNED_BOOT|BOOT_ORDER|BOOT_UART|WAKE_ON_GPIO' || true
          else
            echo "rpi-eeprom-config not found"
          fi
          echo

          echo "== OTP (raw dump if available) =="
          if command -v vcgencmd >/dev/null 2>&1; then
            vcgencmd otp_dump | head -n 12 || true
          else
            echo "vcgencmd not found"
          fi
        '')

        (writeShellScriptBin "pi-secure-boot-sign" ''
          set -euo pipefail

          if [ "$#" -ne 1 ] && [ "$#" -ne 2 ]; then
            echo "Usage: pi-secure-boot-sign <private-key.pem> [source-dir]"
            echo "Default source-dir: ${cfg.otpSecureBoot.firmwareMountPoint}"
            exit 1
          fi

          private_key="$1"
          source_dir="''${2:-${cfg.otpSecureBoot.firmwareMountPoint}}"

          if [ ! -f "$private_key" ]; then
            echo "Private key not found: $private_key" >&2
            exit 1
          fi

          if [ ! -d "$source_dir" ]; then
            echo "Source dir not found: $source_dir" >&2
            exit 1
          fi

          tmp_img="$(mktemp -p /tmp pi-boot-img.XXXXXX.img)"
          trap 'rm -f "$tmp_img"' EXIT

          dd if=/dev/zero of="$tmp_img" bs=1M count=256 status=none
          mkfs.fat -F 32 "$tmp_img" >/dev/null

          shopt -s dotglob nullglob
          files=("$source_dir"/*)
          if [ "''${#files[@]}" -eq 0 ]; then
            echo "No files found in source dir: $source_dir" >&2
            exit 1
          fi
          mcopy -i "$tmp_img" -s "''${files[@]}" ::/

          cp -f "$tmp_img" "${cfg.otpSecureBoot.bootBundlePath}"
          rpi-eeprom-digest \
            -i "${cfg.otpSecureBoot.bootBundlePath}" \
            -o "${cfg.otpSecureBoot.bootSignaturePath}" \
            -k "$private_key"

          echo "Created bundle: ${cfg.otpSecureBoot.bootBundlePath}"
          echo "Created signature: ${cfg.otpSecureBoot.bootSignaturePath}"
        '')

        (writeShellScriptBin "pi-secure-boot-otp-instructions" ''
                    cat <<'EOF'
          Manual OTP enable flow (irreversible):

          1) Verify signed boot artifacts:
             - ${cfg.otpSecureBoot.bootBundlePath}
             - ${cfg.otpSecureBoot.bootSignaturePath}

          2) Validate EEPROM config and test signed boot without burning OTP first.

          3) Burn OTP only after repeated successful cold-boot tests.

          Reference:
          https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#secure-boot
          EOF
        '')
      ];
    })
  ]);
}

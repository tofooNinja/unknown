# TPM 2.0 support module for Raspberry Pi
# Enables TPM hardware, kernel modules, and LUKS auto-unlock via TPM
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.piTpm.enable = lib.mkEnableOption "TPM 2.0 support for Raspberry Pi";

  config = lib.mkIf config.piTpm.enable {
    # TPM device tree overlay (Infineon SLB 9670/9672)
    hardware.raspberry-pi.config.all.dt-overlays = {
      tpm-slb9670 = {
        enable = true;
        params = { };
      };
    };

    # Kernel modules for TPM SPI
    boot.initrd.kernelModules = [
      "tpm_tis_spi"
      "tpm_tis_core"
    ];

    # Enable TPM2 in systemd
    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };

    # Add tpm2-device=auto to crypttab for automatic LUKS unlock
    boot.initrd.luks.devices.crypted.crypttabExtraOpts = [
      "tpm2-device=auto"
    ];

    # TPM tools
    environment.systemPackages = with pkgs; [
      tpm2-tools
      tpm2-tss
    ];
  };
}

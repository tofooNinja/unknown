# TPM 2.0 support module for Raspberry Pi
# Enables TPM hardware, kernel modules, and LUKS auto-unlock via TPM
{ config
, lib
, pkgs
, ...
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
    # The RP1 southbridge on Pi 5 uses DesignWare SPI (spi_dw / spi_dw_mmio).
    # These must be in the initrd so the SPI bus is up before cryptsetup
    # tries to talk to the TPM.
    boot.initrd.kernelModules = [
      "spi_dw"
      "spi_dw_mmio"
      "tpm_tis_core"
      "tpm_tis_spi"
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

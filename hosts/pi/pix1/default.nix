# pix1 - Raspberry Pi 5, NVMe boot (no TPM)
{ inputs
, config
, lib
, pkgs
, nixos-raspberrypi
, ...
}:
{
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k

    ../common.nix
    (lib.custom.relativeToRoot "hosts/common/disks/pi-ssd-luks.nix")
  ];

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    sdDisk = "/dev/mmcblk0";
    ssdDisk = "/dev/nvme0n1";
    swapSize = "8";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "pix1";
    piModel = "pi5";
    bootMedia = "nvme";
    isClusterNode = true;
  };

  # ── PCIe for NVMe ───────────────────────────────────────────────
  hardware.raspberry-pi.config.all.base-dt-params = {
    # forward uart on pi5 to GPIO 14/15 instead of uart-port
    uart0_console.enable = true;
    pciex1 = {
      enable = true;
      value = "on";
    };
    pciex1_gen = {
      enable = true;
      value = "3";
    };
  };

  # Override LUKS device for SSD
  boot.initrd.luks.devices.crypted.device = lib.mkForce "/dev/disk/by-partlabel/disk-ssd-system";

  boot.loader.raspberry-pi = {
    enable = true;
    bootloader = "kernel";
    configurationLimit = 2;
    variant = "5";
  };

  system.stateVersion = "26.05";
}

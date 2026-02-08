# pix0 - Raspberry Pi 5, TPM, NVMe boot
{
  inputs,
  config,
  lib,
  pkgs,
  nixos-raspberrypi,
  ...
}:
{
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4

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
    hostName = "pix0";
    piModel = "pi5";
    bootMedia = "nvme";
    hasTpm = true;
    isClusterNode = true;
  };

  # ── TPM Module ──────────────────────────────────────────────────
  piTpm.enable = true;

  # ── PCIe for NVMe ───────────────────────────────────────────────
  hardware.raspberry-pi.config.all.base-dt-params = {
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

  system.stateVersion = "24.05";
}

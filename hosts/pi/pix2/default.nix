# pix2 - Raspberry Pi 5, USB SSD boot (no TPM)
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
    ssdDisk = "/dev/sda"; # USB SSD
    swapSize = "8";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "pix2";
    piModel = "pi5";
    bootMedia = "usb";
    isClusterNode = true;
  };

  # Override LUKS device for USB SSD
  boot.initrd.luks.devices.crypted.device = lib.mkForce "/dev/disk/by-partlabel/disk-ssd-system";

  boot.loader.raspberry-pi = {
    enable = true;
    bootloader = "kernel";
    configurationLimit = 2;
    variant = "5";
  };

  system.stateVersion = "24.05";
}

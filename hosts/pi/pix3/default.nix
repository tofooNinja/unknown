# pix3 - Raspberry Pi 4, SD card boot
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
    raspberry-pi-4.base

    ../common.nix
    (lib.custom.relativeToRoot "hosts/common/disks/pi-sd-luks.nix")
  ];

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    disk = "/dev/mmcblk0";
    swapSize = "4";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "pix3";
    piModel = "pi4";
    bootMedia = "sd";
    isClusterNode = true;
  };

  boot.loader.raspberry-pi = {
    enable = true;
    bootloader = "kernel";
    configurationLimit = 2;
    variant = "4";
  };

  # Limit journal size for SD card wear
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=50M
  '';

  system.stateVersion = "24.05";
}

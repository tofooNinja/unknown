# pix0 - Raspberry Pi 5, SD card boot
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
    raspberry-pi-5.display-vc4

    ../common.nix
    (lib.custom.relativeToRoot "hosts/common/disks/pi-sd-luks.nix")
  ];

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    disk = "/dev/mmcblk0";
    swapSize = "8";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "pix0";
    piModel = "pi5";
    bootMedia = "sd";
    hasTpm = true;
    isClusterNode = true;
    enableSops = true;
  };

  # TPM overlay (keep for future measured boot when UEFI is fixed)
  piTpm.enable = true;

  boot.loader.raspberry-pi = {
    enable = true;
    bootloader = "kernel";
    configurationLimit = 2;
    variant = "5";
  };

  system.stateVersion = "25.11";
}

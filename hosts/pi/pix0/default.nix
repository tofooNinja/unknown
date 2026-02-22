# pix0 - Raspberry Pi 5, SD card boot, TPM + FIDO2 LUKS unlock
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
    (lib.custom.relativeToRoot "hosts/common/disks/pi-sd-luks.nix")
    (lib.custom.relativeToRoot "hosts/common/disks/pi-longhorn-ssd.nix")
  ];

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    disk = "/dev/mmcblk0";
    ssdDisk = "/dev/nvme0n1";
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

  piTpm.enable = true;

  # FIDO2 tools needed for LUKS unlock on this host
  environment.systemPackages = with pkgs; [ libfido2 ];

  # Longhorn SSD LUKS unlock in initrd
  boot.initrd.luks.devices.crypted-longhorn = {
    device = "/dev/disk/by-partlabel/longhorn";
    allowDiscards = true;
    crypttabExtraOpts = [ "tpm2-device=auto" "fido2-device=auto" ];
  };

  # ── PCIe for NVMe ───────────────────────────────────────────────
  hardware.raspberry-pi.config.all.base-dt-params = {
    uart0_console.enable = false;
    pciex1 = {
      enable = true;
      value = "on";
    };
    pciex1_gen = {
      enable = true;
      value = "3";
    };
  };

  # Classic boot loader (UEFI/measured boot not viable yet — see docs/measured-boot-status.md)
  boot.loader.raspberry-pi = {
    enable = true;
    bootloader = "kernel";
    configurationLimit = 2;
    variant = "5";
  };

  system.stateVersion = "26.05";
}

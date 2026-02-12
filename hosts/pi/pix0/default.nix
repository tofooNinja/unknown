# pix0 - Raspberry Pi 5, TPM, NVMe boot
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
    enableSops = false;
  };

  # ── TPM Module ──────────────────────────────────────────────────
  piTpm.enable = true;

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

  # Override LUKS device for SSD
  boot.initrd.luks.devices.crypted.device = lib.mkForce "/dev/disk/by-partlabel/disk-ssd-system";

  # Keep /tmp on disk for this host to reduce RAM pressure while compiling
  # cgo-heavy derivations (e.g. sops-install-secrets) on the Pi itself.
  boot.tmp.useTmpfs = lib.mkForce false;

  boot.loader.raspberry-pi = {
    enable = true;
    bootloader = "kernel";
    configurationLimit = 2;
    variant = "5";
  };

  system.stateVersion = "25.11";
}

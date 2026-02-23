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
    raspberry-pi-5.display-vc4

    ../common.nix
    (lib.custom.relativeToRoot "hosts/common/disks/pi-sd-luks.nix")
    (lib.custom.relativeToRoot "hosts/common/disks/pi-longhorn-ssd.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/k3s")
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

  # Tang server for network-bound disk encryption (Clevis clients on the LAN)
  services.tang = {
    enable = true;
    listenStream = [ "7654" ];
    ipAddressAllow = [
      "10.13.12.101"
      "10.13.12.110"
      "10.13.12.111"
      "10.13.12.112"
      "10.13.12.113"
      "10.13.12.114"
      "10.13.12.115"
      "10.13.12.116"
      "10.13.12.117"
      "10.13.12.118"
      "10.13.12.119"
    ];
  };
  networking.firewall.allowedTCPPorts = [ 7654 ]; # no-op while firewall.enable=false, but documents intent

  # ── K3s Configuration (uncomment to enable) ────────────────────
  custom.services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    tokenFile = config.sops.secrets."k3s/token".path;
    manifests.enable = true;
  };

  sops.secrets."k3s/token" = {
    sopsFile = "${inputs.nix-secrets}/sops/shared.yaml";
  };

  # ── Nix Cache Key ───────────────────────────────────────────────────
  sops.secrets."pix0/cache_priv_key" = {
    sopsFile = "${inputs.nix-secrets}/sops/shared.yaml";
  };
  nix.settings.secret-key-files = [ config.sops.secrets."pix0/cache_priv_key".path ];

  # Longhorn SSD LUKS unlock in initrd
  boot.initrd.luks.devices.crypted-longhorn = {
    device = "/dev/disk/by-partlabel/longhorn";
    allowDiscards = true;
    crypttabExtraOpts = [
      "tpm2-device=auto"
      "fido2-device=auto"
    ];
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
    variant = "5";
  };

  system.stateVersion = "26.05";
}

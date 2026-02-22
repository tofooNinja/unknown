# pix3 - Raspberry Pi 4, SD card boot
{ inputs
, config
, lib
, pkgs
, nixos-raspberrypi
, ...
}:
{
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-4.base

    ../common.nix
    (lib.custom.relativeToRoot "hosts/common/disks/pi-sd-luks.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/k3s")
  ];

  # ── K3s Configuration (uncomment to enable) ────────────────────
  # custom.services.k3s = {
  #   enable = true;
  #   role = "agent";
  #   serverUrl = "https://pix0:6443";
  #   tokenFile = config.sops.secrets."k3s/token".path;
  # };
  #
  # sops.secrets."k3s/token" = {
  #   sopsFile = "${inputs.nix-secrets}/sops/shared.yaml";
  # };

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

  # Clevis/Tang: auto-unlock LUKS via pix0's Tang server at boot
  boot.initrd.clevis = {
    enable = true;
    useTang = true;
    devices.crypted.secretFile = ./keys/clevis-tang.jwe;
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

  system.stateVersion = "26.05";
}

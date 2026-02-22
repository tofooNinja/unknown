# pix2 - Raspberry Pi 5, SD card boot (no TPM)
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
    swapSize = "8";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "pix2";
    piModel = "pi5";
    bootMedia = "sd";
    isClusterNode = true;
  };

  boot.loader.raspberry-pi = {
    enable = true;
    bootloader = "kernel";
    configurationLimit = 2;
    variant = "5";
  };

  system.stateVersion = "26.05";
}

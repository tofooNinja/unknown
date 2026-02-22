# pix1 - Raspberry Pi 5, SD card boot (no TPM)
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
  custom.services.k3s = {
    enable = false;
    role = "agent";
    serverUrl = "https://pix0:6443";
    tokenFile = config.sops.secrets."k3s/token".path;
  };

  sops.secrets."k3s/token" = {
    sopsFile = "${inputs.nix-secrets}/sops/shared.yaml";
  };

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    disk = "/dev/mmcblk0";
    swapSize = "8";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "pix1";
    piModel = "pi5";
    bootMedia = "sd";
    isClusterNode = true;
  };

  hardware.raspberry-pi.config.all.base-dt-params = {
    # forward uart on pi5 to GPIO 14/15 instead of uart-port
    uart0_console.enable = true;
  };

  # Clevis/Tang: auto-unlock LUKS via pix0's Tang server at boot
  boot.initrd.clevis = {
    enable = true;
    useTang = true;
    devices.crypted.secretFile = ./keys/clevis-tang.jwe;
  };

  # Embed the Clevis secret in the systemd initrd explicitly.
  # This bypasses `boot.initrd.secrets = lib.mkForce {}` in common.nix.
  boot.initrd.systemd.contents."/etc/clevis/crypted.jwe".source = ./keys/clevis-tang.jwe;

  boot.loader.raspberry-pi = {
    enable = true;
    bootloader = "kernel";
    configurationLimit = 2;
    variant = "5";
  };

  system.stateVersion = "26.05";
}

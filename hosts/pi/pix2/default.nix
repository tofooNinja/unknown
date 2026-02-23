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
    hostName = "pix2";
    piModel = "pi5";
    bootMedia = "sd";
    isClusterNode = true;
  };

  # Clevis client: unlocks LUKS volume by contacting a Tang server at boot.
  # Enrollment: see docs/secure-boot-guide.md Part 2.6 for step-by-step instructions.
  # The JWE secret file is created during enrollment and stored at ./keys/clevis-tang.jwe.
  #
  # Known limitation: the JWE file is copied to the Nix store (world-readable).
  # See: https://github.com/NixOS/nixpkgs/issues/335105
  # Mitigation: the JWE can only be decrypted by contacting the Tang server.
  # Keep the Tang server on a trusted private network.
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
    variant = "5";
  };

  system.stateVersion = "26.05";
}

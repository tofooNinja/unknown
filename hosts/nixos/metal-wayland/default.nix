# metal-wayland - MacBook Pro mid-2013, open-source Intel + Wayland
{ inputs
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    (lib.custom.relativeToRoot "hosts/common/core")

    # Disko disk layout
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-luks-disk.nix")

    # Optional host modules
    (lib.custom.relativeToRoot "hosts/common/optional/audio.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/fonts.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/gaming.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/niri.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/stylix.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/bluetooth.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/yubikey-pam.nix")

    # Hardware
    ./hardware.nix
  ];

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    disk = "/dev/sda";
    withSwap = true;
    swapSize = "8";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "metal-wayland";
    isRoaming = true;
    isGaming = true;
    isClusterNode = true;
    useYubikey = true;
    wifi = true;
    useWayland = true;
    defaultDesktop = "niri";
    defaultBrowser = "zen";
    defaultTerminal = "ghostty";
    barChoice = "noctalia";
  };

  # ── Boot ────────────────────────────────────────────────────────
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.networkmanager.enable = true;

  system.stateVersion = "25.11";
}

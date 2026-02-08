# deck - Steam Deck
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
    (lib.custom.relativeToRoot "hosts/common/optional/stylix.nix")

    # Hardware
    ./hardware.nix
  ];

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    disk = "/dev/nvme0n1";
    withSwap = true;
    swapSize = "8";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "deck";
    isRoaming = true;
    isGaming = true;
    wifi = true;
    useWayland = true;
    defaultDesktop = "gamescope";
    defaultBrowser = "zen";
    defaultTerminal = "ghostty";
  };

  # ── Steam Deck Gaming Mode ─────────────────────────────────────
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # ── Boot ────────────────────────────────────────────────────────
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.networkmanager.enable = true;

  system.stateVersion = "25.11";
}

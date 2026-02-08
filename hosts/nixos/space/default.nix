# space - Main AMD desktop, gaming, nix build server
{ inputs
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    (lib.custom.relativeToRoot "hosts/common/core")

    # Optional host modules
    (lib.custom.relativeToRoot "hosts/common/optional/audio.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/fonts.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/gaming.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/niri.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/stylix.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/bluetooth.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/printing.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/syncthing.nix")

    # Hardware
    ./hardware.nix
  ];

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "space";
    isBuildServer = true;
    isGaming = true;
    isDevelopment = true;
    useYubikey = true;
    useWayland = true;
    defaultDesktop = "niri";
    defaultBrowser = "brave";
    defaultTerminal = "ghostty";
    barChoice = "noctalia";
  };

  # ── Build server role ───────────────────────────────────────────
  nix.settings.max-jobs = lib.mkDefault 16;

  # Enable aarch64 emulation for cross-compilation (Pis)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # ── Boot ────────────────────────────────────────────────────────
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.networkmanager.enable = true;

  system.stateVersion = "25.11";
}

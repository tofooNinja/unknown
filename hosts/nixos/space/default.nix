# space - Main AMD desktop, gaming, nix build server
{ inputs
, config
, lib
, pkgs
, ...
}: {
  imports = [
    (lib.custom.relativeToRoot "hosts/common/core")

    # Optional host modules
    (lib.custom.relativeToRoot "hosts/common/optional/audio.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/fonts.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/gaming.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/niri.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/yubikey-pam.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/stylix.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/bluetooth.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/printing.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/syncthing.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/communication.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/ai-code-editors.nix")

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
    useStylix = true;
    defaultShell = "zsh";
    enableCommunicationApps = true;
    aiCodeEditorsEnable = true;
    wallpaper = ../../../wallpapers/Valley.jpg;
  };

  # ── Build server role ───────────────────────────────────────────
  nix.settings.max-jobs = lib.mkDefault 21;

  # Local LAN binary cache for Pis/installers
  # Generate keys once on space:
  #   nix-store --generate-binary-cache-key space-nix-cache-1 cache-priv-key.pem cache-pub-key.pem
  # Store cache-priv-key in nix-secrets/sops/space.yaml as "cache-priv-key"
  # and put cache-pub-key.pem contents in hosts/pi/space-cache-public-key.txt.
  users.users.nix-serve = {
    isSystemUser = true;
    group = "nix-serve";
    description = "Nix binary cache server";
  };
  users.groups.nix-serve = { };

  sops.secrets."cache-priv-key" = {
    sopsFile = "${builtins.toString inputs.nix-secrets}/sops/space.yaml";
    owner = "nix-serve";
    group = "nix-serve";
    mode = "0400";
  };

  services.nix-serve = {
    enable = true;
    bindAddress = "0.0.0.0";
    port = 5000;
    secretKeyFile = config.sops.secrets."cache-priv-key".path;
  };
  networking.firewall.allowedTCPPorts = [ 5000 ];

  # Allow Pis to push freshly built paths back to this machine's nix store.
  nix.sshServe = {
    enable = true;
    write = true;
  };

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

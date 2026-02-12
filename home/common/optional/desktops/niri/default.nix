# Niri home-manager configuration
{ config
, pkgs
, lib
, inputs
, hostSpec
, ...
}:
let
  barChoice = hostSpec.barChoice;

  # Noctalia-shell from flake input (only when barChoice is noctalia)
  noctalia-shell = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    ./config.nix
    ./gtk.nix
    ./qt.nix
  ];

  # Terminal emulator
  programs.ghostty = lib.mkIf (hostSpec.defaultTerminal == "ghostty") {
    enable = true;
  };

  programs.kitty = lib.mkIf (hostSpec.defaultTerminal == "kitty") {
    enable = true;
    settings = {
      background_opacity = "0.85";
      confirm_os_window_close = 0;
    };
  };

  # Application launcher (fuzzel – lightweight Wayland-native launcher)
  programs.fuzzel.enable = true;

  home.packages = with pkgs; [
    # Niri utilities
    swaylock
    grim
    slurp
    swappy
    wl-clipboard
    wl-clip-persist
    cliphist
    xwayland-satellite
    mako
    libnotify
    brightnessctl
    networkmanagerapplet

    # Wallpaper daemon
    swww

    # Display management
    kanshi
    wdisplays

    # Bar (waybar as fallback / alternative)
    waybar

    # File manager
    thunar
  ] ++ lib.optional (barChoice == "noctalia") noctalia-shell;

  # Waybar systemd service for Niri (only when barChoice is waybar)
  systemd.user.services.waybar-niri = lib.mkIf (barChoice == "waybar") {
    Unit = {
      Description = "Waybar status bar (Niri session)";
      PartOf = "graphical-session.target";
      After = "graphical-session.target";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "on-failure";
      RestartSec = "1s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # XWayland satellite service for X11 app support
  systemd.user.services.xwayland-satellite = {
    Unit = {
      Description = "Xwayland outside Wayland";
      BindsTo = "graphical-session.target";
      After = "graphical-session.target";
    };
    Service = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
      StandardOutput = "journal";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}

# Niri home-manager configuration
{
  config,
  pkgs,
  lib,
  hostSpec,
  ...
}:
{
  imports = [
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

  # File manager
  programs.thunar = {
    enable = true;
  };

  # Application launcher
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
  };

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

    # Desktop apps
    thunar
  ];
}

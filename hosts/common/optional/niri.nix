# Niri compositor - system level
{ pkgs, inputs, config, ... }:
{
  imports = [
    inputs.niri.nixosModules.niri
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  # SDDM display manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.sessionPackages = [ pkgs.niri ];

  # XWayland for X11 app compatibility
  programs.xwayland.enable = true;

  # XDG Desktop Portal
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    wl-clip-persist
    cliphist
    xwayland-satellite
    swaylock
    grim
    slurp
    swappy
    mako
    libnotify
    brightnessctl
    networkmanagerapplet
  ];
}

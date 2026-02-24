# Niri compositor - system level
{ pkgs, inputs, config, lib, ... }:
let
  foreground = config.stylix.base16Scheme.base00;
  textColor = config.stylix.base16Scheme.base05;
  sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "pixel_sakura";
    themeConfig =
      if lib.hasSuffix "sakura_static.png" config.stylix.image then
        {
          FormPosition = "left";
          Blur = "2.0";
          HourFormat = "h:mm AP";
        }
      else if lib.hasSuffix "studio.png" config.stylix.image then
        {
          Background = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/anotherhadi/nixy-wallpapers/refs/heads/main/wallpapers/studio.gif";
            sha256 = "sha256-qySDskjmFYt+ncslpbz0BfXiWm4hmFf5GPWF2NlTVB8=";
          };
          HeaderTextColor = "#${textColor}";
          DateTextColor = "#${textColor}";
          TimeTextColor = "#${textColor}";
          HourFormat = "h:mm AP";
          LoginFieldTextColor = "#${textColor}";
          PasswordFieldTextColor = "#${textColor}";
          UserIconColor = "#${textColor}";
          PasswordIconColor = "#${textColor}";
          WarningColor = "#${textColor}";
          LoginButtonBackgroundColor = "#${foreground}";
          SystemButtonsIconsColor = "#${foreground}";
          SessionButtonTextColor = "#${textColor}";
          VirtualKeyboardButtonTextColor = "#${textColor}";
          DropdownBackgroundColor = "#${foreground}";
          HighlightBackgroundColor = "#${textColor}";
        }
      else
        {
          FormPosition = "left";
          Blur = "4.0";
          Background = "${toString config.stylix.image}";
          HeaderTextColor = "#${textColor}";
          DateTextColor = "#${textColor}";
          TimeTextColor = "#${textColor}";
          HourFormat = "h:mm AP";
          LoginFieldTextColor = "#${textColor}";
          PasswordFieldTextColor = "#${textColor}";
          UserIconColor = "#${textColor}";
          PasswordIconColor = "#${textColor}";
          WarningColor = "#${textColor}";
          LoginButtonBackgroundColor = "#${config.stylix.base16Scheme.base01}";
          SystemButtonsIconsColor = "#${textColor}";
          SessionButtonTextColor = "#${textColor}";
          VirtualKeyboardButtonTextColor = "#${textColor}";
          DropdownBackgroundColor = "#${config.stylix.base16Scheme.base01}";
          HighlightBackgroundColor = "#${textColor}";
          FormBackgroundColor = "#${config.stylix.base16Scheme.base01}";
        };
  };
in
{
  imports = [
    inputs.niri.nixosModules.niri
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  # SDDM display manager with sddm-astronaut theme
  services.displayManager.sddm = {
    package = pkgs.kdePackages.sddm;
    extraPackages = [ sddm-astronaut ];
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
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
    sddm-astronaut
    wl-clipboard
    wl-clip-persist
    cliphist
    xwayland-satellite
    xorg.xhost
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

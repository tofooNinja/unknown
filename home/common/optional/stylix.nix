# Home-manager Stylix targets (complement system-level stylix)
# Disable targets we do not use; enable ghostty/qt; enable nwg-drawer theming
{ config
, lib
, hostSpec
, ...
}:
{
  stylix.targets = {
    waybar.enable = false;
    rofi.enable = false;
    hyprland.enable = false;
    hyprlock.enable = false;
    ghostty.enable = true;
    qt.enable = true;
    qt.platform = "qtct";
  };

  services.nwg-drawer-stylix.enable = true;
}

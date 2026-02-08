# i3 - X11 tiling WM (fallback when not on Wayland)
{ config
, pkgs
, lib
, hostSpec
, ...
}:
let
  terminal = hostSpec.defaultTerminal;
  termPkg =
    if terminal == "ghostty"
    then pkgs.ghostty
    else pkgs.${terminal};
  mod = "Mod4";
in
{
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = mod;
      terminal = "${termPkg}/bin/${terminal}";
      menu = "${pkgs.fuzzel}/bin/fuzzel";

      gaps = {
        inner = 5;
        outer = 5;
      };

      keybindings = lib.mkOptionDefault {
        "${mod}+Return" = "exec ${termPkg}/bin/${terminal}";
        "${mod}+d" = "exec ${pkgs.fuzzel}/bin/fuzzel";
        "${mod}+Shift+q" = "kill";
        "${mod}+Shift+e" = "exec i3-msg exit";

        "${mod}+h" = "focus left";
        "${mod}+j" = "focus down";
        "${mod}+k" = "focus up";
        "${mod}+l" = "focus right";

        "${mod}+Shift+h" = "move left";
        "${mod}+Shift+j" = "move down";
        "${mod}+Shift+k" = "move up";
        "${mod}+Shift+l" = "move right";
      };

      startup = [
        {
          command = "${pkgs.feh}/bin/feh --bg-fill ${toString hostSpec.wallpaper}";
          notification = false;
        }
        {
          command = "${pkgs.networkmanagerapplet}/bin/nm-applet";
          notification = false;
        }
      ];

      bars = [
        {
          statusCommand = "${pkgs.i3status}/bin/i3status";
          position = "top";
        }
      ];
    };
  };

  home.packages = with pkgs; [
    feh
    i3status
    fuzzel
  ];
}

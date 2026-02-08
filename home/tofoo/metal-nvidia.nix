# Host-specific home config for metal-nvidia
{
  hostSpec,
  pkgs,
  lib,
  ...
}:
{
  # Metal nvidia-specific: uses kitty, X11/i3/sway
  programs.kitty = {
    enable = true;
    settings = {
      background_opacity = lib.mkForce "0.85";
      confirm_os_window_close = 0;
    };
  };
}

# Home media center and retro console module for Raspberry Pi
# Can be assigned to any Pi via hostSpec.isHomeMedia
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.piHomeMedia.enable = lib.mkEnableOption "Home media center and retro console";

  config = lib.mkIf config.piHomeMedia.enable {
    # Kodi media center
    services.xserver.enable = true;

    # Use cage as a kiosk-mode Wayland compositor for Kodi
    services.cage = {
      enable = true;
      user = config.hostSpec.primaryUsername;
      program = "${pkgs.kodi-wayland}/bin/kodi";
    };

    # Audio output configuration
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;

    # RetroArch for retro gaming
    environment.systemPackages = with pkgs; [
      kodi-wayland
      retroarch
      # Common RetroArch cores
      libretro.snes9x
      libretro.nestopia
      libretro.genesis-plus-gx
      libretro.mgba
      libretro.beetle-psx-hw
      libretro.mupen64plus
      # Media utilities
      ffmpeg
      vlc
    ];

    # Enable HDMI audio
    hardware.raspberry-pi.config.all = {
      options = {
        hdmi_drive = {
          enable = true;
          value = 2; # Force HDMI audio output
        };
      };
    };

    # Bluetooth for controllers
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;

    # Open firewall for DLNA/UPnP
    networking.firewall = {
      allowedTCPPorts = [ 8080 ];
      allowedUDPPorts = [ 1900 ];
    };
  };
}

# Audio via PipeWire
{ pkgs, ... }:
{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Disable PulseAudio (conflicts with PipeWire)
  services.pulseaudio.enable = false;

  # rtkit is recommended for PipeWire
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    pavucontrol
    playerctl
    pamixer
  ];
}

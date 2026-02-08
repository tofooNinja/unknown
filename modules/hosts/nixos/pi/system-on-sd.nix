# Pi system booting from SD card
# Imports the SD card disko layout and configures SD-specific settings
{
  config,
  lib,
  ...
}:
{
  imports = [
    (lib.custom.relativeToRoot "hosts/common/disks/pi-sd-luks.nix")
  ];

  # SD card wear-leveling optimizations
  boot.tmp.useTmpfs = true;

  # Limit journal size to reduce writes
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=50M
  '';
}

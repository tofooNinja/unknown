# Pi system booting from NVMe/USB SSD
# Imports the SSD disko layout and configures SSD-specific settings
{
  config,
  lib,
  ...
}:
{
  imports = [
    (lib.custom.relativeToRoot "hosts/common/disks/pi-ssd-luks.nix")
  ];

  boot.tmp.useTmpfs = true;
}

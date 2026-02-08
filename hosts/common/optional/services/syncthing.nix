# Syncthing - continuous file synchronization
{ config, lib, pkgs, ... }:
{
  services.syncthing = {
    enable = true;
    user = config.hostSpec.primaryUsername;
    dataDir = config.hostSpec.home;
    configDir = "${config.hostSpec.home}/.config/syncthing";
    openDefaultPorts = true; # Opens TCP 22000 and UDP 22000/21027
  };
}

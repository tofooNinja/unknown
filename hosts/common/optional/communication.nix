# Communication apps - Telegram, Vesktop, Signal
{ config, lib, pkgs, ... }:
lib.mkIf (config.hostSpec.enableCommunicationApps or false) {
  environment.systemPackages = with pkgs; [
    telegram-desktop
    vesktop
    signal-desktop
  ];
}

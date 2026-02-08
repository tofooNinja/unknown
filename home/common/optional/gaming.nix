# Gaming home-manager config
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mangohud
    gamemode
  ];
}

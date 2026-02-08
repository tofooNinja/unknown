# Personal bashrc template (sourced by bash if present)
{ pkgs, ... }:
{
  home.packages = with pkgs; [ bash ];

  home.file.".bashrc-personal".text = ''
    # Personal aliases and functions - edit this file
    # Examples:
    # export EDITOR="nvim"
    # alias c="clear"
  '';
}

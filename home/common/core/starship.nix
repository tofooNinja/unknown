# Starship prompt
{ pkgs, ... }:
{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "$all";
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[✗](bold red)";
      };
      directory = {
        truncation_length = 3;
        fish_style_pwd_dir_length = 1;
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
      };
      nix_shell = {
        format = "[$symbol$state( \\($name\\))]($style) ";
        symbol = "❄️ ";
      };
    };
  };
}

# VS Code - extensions and config
{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      jeff-hykin.better-nix-syntax
      ms-vscode.cpptools-extension-pack
      vscodevim.vim
      mads-hartmann.bash-ide-vscode
      tamasfe.even-better-toml
      zainchen.json
    ];
  };
}

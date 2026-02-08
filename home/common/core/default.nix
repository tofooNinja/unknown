# Core home-manager configuration - imported by all users on all hosts
{ config
, pkgs
, lib
, hostSpec
, ...
}:
{
  imports = [
    ./git.nix
    ./shell.nix
    ./starship.nix
  ];

  home.packages = with pkgs; [
    # File management
    tree
    fd
    ripgrep
    eza
    bat
    fzf
    jq
    yq-go
    duf
    ranger

    # System
    btop
    neofetch
    pciutils
    usbutils
    lshw

    # Editors
    neovim

    # Version control
    tig
    lazygit

    # Networking
    curl
    wget

    # Docs
    tealdeer

    rpi-imager
  ];

  programs.home-manager.enable = true;

  # XDG base directories
  xdg = {
    enable = true;
    userDirs.enable = true;
  };
}

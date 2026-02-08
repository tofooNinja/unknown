# Core home-manager configuration - imported by all users on all hosts
{ config
, pkgs
, lib
, hostSpec
, ...
}:
{
  imports = [
    # Shell and prompt
    ./git.nix
    ./shell.nix
    ./starship.nix
    ./bash.nix
    ./bashrc-personal.nix
    ./environment.nix

    # CLI tool configs
    ./bat.nix
    ./btop.nix
    ./cava.nix
    ./emoji.nix
    ./eza.nix
    ./fzf.nix
    ./gh.nix
    ./ssh.nix
    ./tealdeer.nix
    ./zoxide.nix
  ];

  home.packages = with pkgs; [
    # File management
    tree
    fd
    ripgrep
    jq
    yq-go
    duf
    ranger

    # System
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

    rpi-imager
  ];

  programs.home-manager.enable = true;

  # XDG base directories
  xdg = {
    enable = true;
    userDirs.enable = true;
  };
}

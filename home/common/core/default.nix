# Core home-manager configuration - imported by all users on all hosts
{ config
, pkgs
, lib
, hostSpec
, ...
}:
let
  browserPackage =
    if hostSpec.defaultBrowser == "brave" then pkgs.brave
    else if hostSpec.defaultBrowser == "firefox" then pkgs.firefox
    else if hostSpec.defaultBrowser == "chromium" then pkgs.chromium
    else if hostSpec.defaultBrowser == "zen" && lib.hasAttrByPath [ "zen-browser" ] pkgs
    then lib.getAttrFromPath [ "zen-browser" ] pkgs
    else null;
in
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
    ./scripts
  ];

  home.packages = with pkgs; [
    python3
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
    nixfmt

    # Version control
    tig
    lazygit

    # Networking
    curl
    wget

    screen
  ] ++ lib.optionals (!hostSpec.isPi) [
    rpi-imager
    google-antigravity
  ] ++ lib.optionals (!hostSpec.isServer && browserPackage != null) [ browserPackage ];

  programs.home-manager.enable = true;

  # XDG base directories
  xdg = {
    enable = true;
    userDirs.enable = true;
  };
}

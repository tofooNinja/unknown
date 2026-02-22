# Core configuration - imported by ALL hosts
{ inputs
, config
, lib
, pkgs
, secrets
, ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko

    (lib.custom.relativeToRoot "modules/common/host-spec.nix")

    ./sops.nix
    ./ssh.nix
    ./locale.nix
    ./nix.nix
    ./flatpak.nix

    (lib.custom.relativeToRoot "hosts/common/users")
  ];

  # ── Core Host Specifications ────────────────────────────────────
  hostSpec = {
    inherit
      (secrets)
      domain
      email
      userFullName
      networking
      ;
  };

  networking.hostName = config.hostSpec.hostName;

  # System-wide packages
  environment.systemPackages = with pkgs; [
    openssh
    git
    python3
    vim
    curl
    wget
    tree
    btop
    rsync
    nh
    sops
    ssh-to-age
    ranger
  ];

  # Home-manager backup extension for conflicting files
  home-manager.backupFileExtension = "bk";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Basic shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;
}

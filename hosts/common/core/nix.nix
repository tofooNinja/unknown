# Nix daemon and flake settings
{ config
, lib
, pkgs
, ...
}: {
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" config.hostSpec.primaryUsername ];
      auto-optimise-store = true;
      download-buffer-size = 2000000000;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}

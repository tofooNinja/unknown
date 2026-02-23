# Nix daemon and flake settings
{ config
, lib
, pkgs
, ...
}:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        config.hostSpec.primaryUsername
      ];
      auto-optimise-store = true;
      download-buffer-size = 2000000000;
      extra-trusted-public-keys = [ "pix0:fP71I43aOjEzXyjhphwlzjSzXlWCIdjmzERC6bL+WWs=" ];
    };

    distributedBuilds = lib.mkIf (config.hostSpec.hostName != "pix0") true;
    buildMachines = lib.mkIf (config.hostSpec.hostName != "pix0") [
      {
        hostName = "pix0.local";
        system = "aarch64-linux";
        protocol = "ssh-ng";
        maxJobs = 4;
        speedFactor = 2;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
      }
    ];

    # Enable automatic store optimization (fixing inconsistencies and hardlinking)
    optimise.automatic = true;

    gc = {
      automatic = true;
      dates = "weekly";
      options = if config.hostSpec.isPi then "--delete-generations +4" else "--delete-generations +15";
    };
  };

  # Match systemd-boot entries to our GC generation policy for x86 hosts.
  # (Pi limits are handled in hosts/pi configurations)
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 15;
}

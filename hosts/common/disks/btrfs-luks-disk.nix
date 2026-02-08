# Parameterized BTRFS + LUKS disk layout for PCs
# No impermanence - standard persistent root
{
  lib,
  pkgs,
  disk ? "/dev/vda",
  withSwap ? false,
  swapSize ? "16",
  ...
}:
{
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "encrypted-nixos";
                passwordFile = "/tmp/disko-password";
                settings = {
                  allowDiscards = true;
                  crypttabExtraOpts = [
                    "fido2-device=auto"
                    "token-timeout=10"
                  ];
                };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@swap" = lib.mkIf withSwap {
                      mountpoint = "/.swapvol";
                      swap.swapfile.size = "${swapSize}G";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  environment.systemPackages = [
    pkgs.yubikey-manager # For LUKS FIDO2 enrollment
  ];
}

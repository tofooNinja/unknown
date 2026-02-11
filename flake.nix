{
  description = "tofoo's unified NixOS configuration";

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  inputs = {
    # ── Core ──────────────────────────────────────────────────────
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Hardware ──────────────────────────────────────────────────
    nixos-hardware.url = "github:nixos/nixos-hardware";

    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
    };

    # ── Utilities ─────────────────────────────────────────────────
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Desktop / Ricing ──────────────────────────────────────────
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Secrets ───────────────────────────────────────────────────
    nix-secrets = {
      url = "git+file:///home/tofoo/new_beginning/matrix/nix-secrets";
      # url = "git+ssh://git@github.com/tofooNinja/unknown-secrets.git?ref=main&shallow=1";
      flake = true;
    };
  };

  outputs =
    { self
    , nixpkgs
    , ...
    } @ inputs:
    let
      inherit (nixpkgs) lib;

      # Extend lib with our custom helpers
      customLib = lib.extend (
        _self: _super: {
          custom = import ./lib { inherit lib; };
        }
      );

      secrets = inputs.nix-secrets;

      # Extend the nixos-raspberrypi fork's lib with our custom helpers.
      # Pi builds must use the fork's lib (not upstream) so that its
      # key-based mkRemovedOptionModule deduplication works correctly.
      piLib = inputs.nixos-raspberrypi.inputs.nixpkgs.lib;
      piCustomLib = piLib.extend (
        _self: _super: {
          custom = import ./lib { lib = piLib; };
        }
      );

      # ── Host builder for x86_64-linux PCs ─────────────────────────
      mkHost = hostName: {
        ${hostName} = lib.nixosSystem {
          specialArgs = {
            inherit inputs secrets;
            lib = customLib;
          };
          modules = [
            ./hosts/nixos/${hostName}
          ];
        };
      };

      # ── Host builder for aarch64-linux Pis ────────────────────────
      # Uses nixos-raspberrypi.lib.nixosSystemFull which provides:
      #   - The compatible forked nixpkgs (avoids rename.nix / libraspberrypi conflicts)
      #   - All required overlays (kernel, firmware, vendor packages)
      #   - Trusted binary cache configuration
      mkPiHost = hostName: {
        ${hostName} = inputs.nixos-raspberrypi.lib.nixosSystemFull {
          specialArgs = {
            inherit inputs secrets;
            lib = piCustomLib;
            nixos-raspberrypi = inputs.nixos-raspberrypi;
            spaceCachePublicKey = spaceCachePublicKey;
          };
          modules = [
            spaceCacheModule
            ./hosts/pi/${hostName}
          ];
        };
      };

      # Merge a list of attrsets into one
      mergeHosts = hosts: lib.foldl (acc: set: acc // set) { } hosts;

      # Optional: space (10.13.12.101) as Nix cache. Create hosts/pi/space-cache-public-key.txt
      # with the cache public key (from nix-store --generate-binary-cache-key on space) to enable.
      spaceCacheKeyPath = self + "/hosts/pi/space-cache-public-key.txt";
      spaceCachePublicKey =
        if builtins.pathExists spaceCacheKeyPath
        then builtins.replaceStrings [ "\n" "\r" ] [ "" "" ] (builtins.readFile spaceCacheKeyPath)
        else "";

      # SSH keys for installer images (root + nixos), from tofoo keys (same as host logins)
      installerKeyDir = self + "/hosts/common/users/tofoo/keys";
      installerKeyFiles = lib.filesystem.listFilesRecursive installerKeyDir;
      installerAuthorizedKeys = map lib.readFile (
        builtins.filter (p: lib.hasSuffix ".pub" (toString p)) installerKeyFiles
      );

      # Shared module for using "space" as binary cache and optional SSH push target.
      # Kept inline so flake evaluation does not depend on untracked files.
      spaceCacheModule = { config, lib, pkgs, ... }:
        let
          cfg = config.spaceCache;
          cacheUrl = "http://${cfg.host}:${toString cfg.port}";
          pushStore = "ssh://${cfg.sshUser}@${cfg.host}";
        in
        {
          options.spaceCache = {
            enable = lib.mkEnableOption "Use space (or configured host) as Nix substituter and optional push target";
            host = lib.mkOption {
              type = lib.types.str;
              default = "10.13.12.101";
            };
            port = lib.mkOption {
              type = lib.types.port;
              default = 5000;
            };
            publicKey = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            pushOverSsh = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
            sshUser = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
          };

          config = lib.mkIf (cfg.enable && cfg.publicKey != "") {
            nix.settings = {
              extra-substituters = [ cacheUrl ];
              extra-trusted-public-keys = [ cfg.publicKey ];
              post-build-hook = lib.mkIf cfg.pushOverSsh (toString (pkgs.writeShellScript "nix-copy-to-space" ''
                set -eu
                set -f
                export IFS=' '
                if [ -n "''${OUT_PATHS:-}" ]; then
                  echo "Uploading to ${pushStore}: $OUT_PATHS"
                  exec ${pkgs.nix}/bin/nix copy --to "${pushStore}" $OUT_PATHS
                fi
              ''));
            };
          };
        };

      # Minimal Pi installer configs (no disko/sops). Build with aarch64 native
      # (on a Pi or remote builder) to avoid slow cross-compilation.
      rpi = inputs.nixos-raspberrypi;
      mkPiInstaller = variant: rpiModules: rpi.lib.nixosInstaller {
        specialArgs = {
          nixos-raspberrypi = rpi;
          installerAuthorizedKeys = installerAuthorizedKeys;
          spaceCachePublicKey = spaceCachePublicKey;
        };
        modules = [
          ({ config, pkgs, nixos-raspberrypi, ... }: {
            imports = with nixos-raspberrypi.nixosModules; rpiModules;
          })
          ({ config, installerAuthorizedKeys ? [ ], ... }: {
            users.users.nixos.openssh.authorizedKeys.keys = installerAuthorizedKeys;
            users.users.root.openssh.authorizedKeys.keys = installerAuthorizedKeys;
          })
          spaceCacheModule
          # Use space (10.13.12.101) as Nix substituter when space-cache-public-key.txt is present.
          # Push is disabled on the installer (no SSH key to space by default).
          ({ config, spaceCachePublicKey ? "", ... }: {
            spaceCache = {
              enable = true;
              host = "10.13.12.101";
              port = 5000;
              publicKey = spaceCachePublicKey;
              pushOverSsh = false;
            };
          })
        ];
      };

      pix5-installer = mkPiInstaller "5" [
        rpi.nixosModules.raspberry-pi-5.base
        rpi.nixosModules.raspberry-pi-5.page-size-16k
      ];
      pix4-installer = mkPiInstaller "4" [
        rpi.nixosModules.raspberry-pi-4.base
      ];
    in
    {
      overlays = import ./overlays { inherit inputs lib; };

      nixosConfigurations = mergeHosts [
        # PCs (x86_64-linux)
        (mkHost "space")
        (mkHost "black")
        (mkHost "metal-nvidia")
        (mkHost "metal-wayland")
        (mkHost "deck")
        # Pis (aarch64-linux)
        (mkPiHost "pix0")
        (mkPiHost "pix1")
        (mkPiHost "pix2")
        (mkPiHost "pix3")
        # Pi installer images (minimal SD image; build on Pi to avoid cross-compilation)
        { pix5-installer = pix5-installer; }
        { pix4-installer = pix4-installer; }
      ];

      # SD card images for installing NixOS on Pi. Build on aarch64 (e.g. on the Pi
      # or via remote builder) to avoid slow cross-compilation and sops-install-secrets.
      # Usage: nix build .#packages.aarch64-linux.createInstallSD-pix5
      # From x86_64: use a remote aarch64 builder or build on the Pi.
      packages.aarch64-linux = {
        createInstallSD-pix5 = pix5-installer.config.system.build.sdImage;
        createInstallSD-pix4 = pix4-installer.config.system.build.sdImage;
      };

      # Dev shell for bootstrapping and secrets management
      devShells = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              nil
              nixpkgs-fmt
              nix-output-monitor
              sops
              ssh-to-age
              age
              yubikey-manager
              yubikey-personalization
            ];
          };
        }
      );
    };
}

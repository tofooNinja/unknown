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
      url = "git+ssh://git@github.com/tofooNinja/unknown-secrets.git?ref=main&shallow=1";
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
          };
          modules = [
            ./hosts/pi/${hostName}
          ];
        };
      };

      # Merge a list of attrsets into one
      mergeHosts = hosts: lib.foldl (acc: set: acc // set) { } hosts;
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
      ];

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

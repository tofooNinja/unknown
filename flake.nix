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
    # For local development, use git+file with absolute path.
    # For production, change to: git+ssh://git@gitlab.com/<user>/nix-secrets.git?ref=main&shallow=1
    nix-secrets = {
      url = "git+file:///home/tofoo/new_beginning/matrix/nix-secrets";
      flake = true;
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
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
    mkPiHost = hostName: {
      ${hostName} = lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          inherit inputs secrets;
          lib = customLib;
          nixos-raspberrypi = inputs.nixos-raspberrypi;
        };
        modules = [
          # Disable nixpkgs' removed-option entry for boot.loader.raspberryPi
          # which conflicts with nixos-raspberrypi's custom bootloader module
          {
            disabledModules = [
              { key = "removedOptionModule#boot_loader_raspberryPi"; }
            ];
          }
          # nixos-raspberrypi overlays for kernel, firmware, vendor packages
          inputs.nixos-raspberrypi.lib.inject-overlays
          inputs.nixos-raspberrypi.lib.inject-overlays-global
          inputs.nixos-raspberrypi.nixosModules.trusted-nix-caches
          # Host-specific config
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
    devShells = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
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

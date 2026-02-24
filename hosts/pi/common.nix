# Common configuration shared by all Raspberry Pi hosts
{ config
, inputs
, lib
, pkgs
, nixos-raspberrypi
, secrets
, spaceCachePublicKey ? ""
, ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko

    (lib.custom.relativeToRoot "modules/common/host-spec.nix")
    (lib.custom.relativeToRoot "modules/hosts/nixos/pi/measured-boot.nix")
    (lib.custom.relativeToRoot "modules/hosts/nixos/pi/tpm.nix")
    (lib.custom.relativeToRoot "modules/hosts/nixos/pi/secure-native-boot.nix")

    (lib.custom.relativeToRoot "hosts/common/core/sops.nix")
    (lib.custom.relativeToRoot "hosts/common/core/ssh.nix")
    (lib.custom.relativeToRoot "hosts/common/core/locale.nix")
    (lib.custom.relativeToRoot "hosts/common/core/nix.nix")
    (lib.custom.relativeToRoot "hosts/common/users")
  ];

  # Use space (10.13.12.101) as Nix cache when hosts/pi/space-cache-public-key.txt exists.
  # Substituter + push so the Pi fetches from space and uploads new builds.
  spaceCache = lib.mkIf (spaceCachePublicKey != "") {
    enable = true;
    host = "10.13.12.101";
    port = 5000;
    publicKey = spaceCachePublicKey;
    # Enabled automatic build pushing to space.
    # The hook is now non-fatal to avoid activation failures if space is unreachable.
    pushOverSsh = true;
  };

  # ── Core Host Specifications ────────────────────────────────────
  hostSpec = {
    isPi = true;
    isServer = true;
    defaultDesktop = "none"; # Pis are headless - no desktop environment
    inherit (secrets)
      domain
      email
      userFullName
      networking
      ;
  };

  networking.hostName = config.hostSpec.hostName;

  # Allow unfree
  nixpkgs.config.allowUnfree = true;

  # Trust nixos-raspberrypi cache so remote builds (nixos-rebuild --build-host) can substitute
  nix.settings."extra-substituters" = [ "https://nixos-raspberrypi.cachix.org" ];
  nix.settings."extra-trusted-public-keys" = [ "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=" ];

  # Home-manager
  home-manager.backupFileExtension = "bk";

  # Basic shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  # Pi firmware config.txt
  hardware.raspberry-pi.config.all = {
    options = {
      uart_2ndstage = {
        enable = true;
        value = true;
      };
    };
  };

  piSecurity = {
    enable = true;
    useVendorFirmwareDeviceTree = true;
    tpmWithPin.enable = lib.mkDefault config.hostSpec.hasTpm;
    canary = {
      enable = true;
      ntfyChannel = "M9qm8AolDtJA5L5f";
    };
    otpSecureBoot.enable = lib.mkDefault (config.hostSpec.piModel == "pi5");
  };

  # Fix for no screen out during password prompt
  boot.blacklistedKernelModules = [ "vc4" ];
  systemd.services.modprobe-vc4 = {
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    before = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    script = "/run/current-system/sw/bin/modprobe vc4";
  };

  boot = {
    tmp.useTmpfs = true;

    kernelParams = [ "ip=dhcp" "rd.neednet=1" ];

    supportedFilesystems = [ "ext4" "vfat" ];

    initrd = {
      kernelModules = [
        "uas"
        "usbcore"
        "usb_storage"
        "vfat"
        "nls_cp437"
        "nls_iso8859_1"
        "ext4"
        "hid_generic"
        "usbhid"
      ];

      availableKernelModules = [ "hid" "evdev" ];

      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 42069;
          hostKeys = [ "/etc/ssh/initrd_host_ed25519_key" ];
          authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
        };
      };

      systemd = {
        enable = true;
        network.enable = true;
        contents."/etc/ssh/initrd_host_ed25519_key".source =
          lib.custom.relativeToRoot "hosts/pi/keys/initrd_host_ed25519";
      };

      # The NixOS initrd-ssh module unconditionally populates
      # boot.initrd.secrets, which generates an append-initrd-secrets
      # script that runs at bootloader-install time.  During
      # nixos-anywhere the flake source store path is unavailable on
      # the freshly formatted target, so the cp fails.  Since we
      # embed the key at build time via systemd.contents above, the
      # append mechanism is unnecessary.
      secrets = lib.mkForce { };

      luks.devices.crypted = {
        device = "/dev/disk/by-partlabel/disk-sd-system";
        allowDiscards = true;
        crypttabExtraOpts = [ "fido2-device=auto" ];
      };
    };
  };

  boot.loader.raspberry-pi.configurationLimit = lib.mkDefault 4;

  # Networking
  networking = {
    useNetworkd = true;
    firewall.enable = false;
  };

  systemd.network = {
    enable = true;
    wait-online.enable = false;
    networks = {
      "10-eth-default" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "yes";
          MulticastDNS = "yes";
        };
        # Ensure the DHCP client sends the hostname to the router for .lan resolution
        dhcpV4Config.UseHostname = true;
      };
    };
  };

  # Enable mDNS so Pis are reachable as <hostname>.local
  services.resolved = {
    enable = true;
    extraConfig = ''
      MulticastDNS=yes
    '';
  };

  systemd.services = {
    systemd-networkd.stopIfChanged = false;
    systemd-resolved.stopIfChanged = false;
  };

  # SSH - Pis need root login for remote deployment/rescue
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "yes";
  };

  security = {
    polkit.enable = true;
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };

  # System packages - minimal set for k3s cluster nodes
  environment.systemPackages = with pkgs; [
    clevis
    libfido2
    neovim
    git
    ripgrep
    tree
    btop
    duf
    lshw
    pciutils
    usbutils
    raspberrypi-eeprom
  ];
}

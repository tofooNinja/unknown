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
    (lib.custom.relativeToRoot "modules/hosts/nixos/pi/usb-disk.nix")
    (lib.custom.relativeToRoot "modules/hosts/nixos/pi/tpm.nix")
    (lib.custom.relativeToRoot "modules/hosts/nixos/pi/home-media.nix")

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
    pushOverSsh = true;
  };

  # ── Core Host Specifications ────────────────────────────────────
  hostSpec = {
    isPi = true;
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

  # Fix for no screen output during password prompt
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

    kernelParams = [ "ip=dhcp" ];

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
          hostKeys = [
            (lib.custom.relativeToRoot "hosts/pi/keys/initrd_host_ed25519")
          ];
          authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
        };
      };

      systemd = {
        enable = true;
        network.enable = true;
      };

      luks.devices.crypted = {
        device = "/dev/disk/by-partlabel/disk-sd-system";
        allowDiscards = true;
        crypttabExtraOpts = [ "fido2-device=auto" ];
      };
    };
  };

  # Networking
  networking = {
    useNetworkd = true;
    firewall.enable = false;
  };

  systemd.network = {
    enable = true;
    wait-online.enable = false;
    networks = {
      "99-ethernet-default-dhcp".networkConfig.MulticastDNS = "yes";
    };
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

  services.getty.autologinUser = config.hostSpec.primaryUsername;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    neovim
    git
    tree
    btop
    duf
    lshw
    pciutils
    usbutils
    screen
    minicom
    libfido2
    yubikey-manager
    raspberrypi-eeprom
  ];
}

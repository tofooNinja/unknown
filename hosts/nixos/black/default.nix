# black - NVIDIA laptop, gaming, cluster node
{ inputs
, config
, lib
, pkgs
, ...
}:
{
  imports = [
    (lib.custom.relativeToRoot "hosts/common/core")

    # Disko disk layout
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-luks-disk.nix")

    # Optional host modules
    (lib.custom.relativeToRoot "hosts/common/optional/audio.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/fonts.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/gaming.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/niri.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/yubikey-pam.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/stylix.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/bluetooth.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/printing.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/syncthing.nix")

    # Hardware
    ./hardware.nix
  ];

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    disk = "/dev/nvme0n1";
    withSwap = true;
    swapSize = "16";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "black";
    isRoaming = true;
    isGaming = true;
    isDevelopment = true;
    isClusterNode = true;
    useYubikey = true;
    wifi = true;
    useWayland = true;
    defaultDesktop = "niri";
    defaultBrowser = "brave";
    defaultTerminal = "ghostty";
    barChoice = "noctalia";
    useStylix = true;
  };

  # ── NVIDIA ──────────────────────────────────────────────────────
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # Use open source kernel modules (Turing+ GPU)
    package = config.boot.kernelPackages.nvidiaPackages.production;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
  boot.kernelParams = [ "nvidia_drm.fbdev=1" ];

  # ASUS laptop services
  services.supergfxd.enable = true;
  services.asusd = {
    enable = true;
    enableUserService = true;
  };

  # ── Boot ────────────────────────────────────────────────────────
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.networkmanager.enable = true;

  system.stateVersion = "25.11";
}

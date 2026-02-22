# metal-nvidia - MacBook Pro mid-2013, NVIDIA legacy + X11
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
    (lib.custom.relativeToRoot "hosts/common/optional/stylix.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/services/bluetooth.nix")
    (lib.custom.relativeToRoot "hosts/common/optional/yubikey-pam.nix")

    # Hardware
    ./hardware.nix
  ];

  # ── Disko arguments ─────────────────────────────────────────────
  _module.args = {
    disk = "/dev/sda";
    withSwap = true;
    swapSize = "8";
  };

  # ── Host Specification ──────────────────────────────────────────
  hostSpec = {
    hostName = "metal-nvidia";
    isRoaming = true;
    isGaming = true;
    isClusterNode = true;
    useYubikey = true;
    wifi = true;
    useWayland = false;
    useX11 = true;
    defaultDesktop = "i3";
    defaultBrowser = "zen";
    defaultTerminal = "kitty";
    barChoice = "noctalia";
  };

  # ── Display Manager & Desktop (X11) ────────────────────────────
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    windowManager.i3.enable = true;
  };
  services.displayManager.defaultSession = "sway";
  services.desktopManager.gnome.enable = true;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export WLR_DRM_NO_MODIFIERS=1
    '';
    extraPackages = with pkgs; [
      swaylock
      swayidle
      wl-clipboard
      mako
      alacritty
      dmenu
    ];
  };

  # Niri disabled on this target
  programs.niri.enable = false;

  # ── NVIDIA Legacy ───────────────────────────────────────────────
  nixpkgs.config.nvidia.acceptLicense = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = lib.mkForce false;
    open = false; # Legacy Kepler GPU - must use proprietary modules
    package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.legacy_470;
    powerManagement.finegrained = lib.mkForce false;
    prime = {
      offload.enable = lib.mkForce false;
      offload.enableOffloadCmd = lib.mkForce false;
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  services.supergfxd.enable = true;

  environment.sessionVariables = {
    WLR_DRM_NO_MODIFIERS = "1";
  };

  # ── Boot ────────────────────────────────────────────────────────
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.networkmanager.enable = true;

  system.stateVersion = "26.05";
}

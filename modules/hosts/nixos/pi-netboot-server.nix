# Serve a NixOS/Raspberry Pi netboot image over HTTP so Pis set to network boot
# can fetch it. Optional: run dnsmasq in DHCP proxy mode so the existing DHCP
# server keeps assigning IPs while we advertise the boot server (option 66/67).
#
# Prerequisites:
# - Copy or symlink your image (e.g. nixos-image-rpi5-kernel.img) into serveDir
#   on the server: e.g. /var/lib/pi-netboot/nixos-image-rpi5-kernel.img
# - On each Pi: set EEPROM boot order to try network (e.g. BOOT_ORDER=0xf421).
#   One-time: sudo rpi-eeprom-config --edit (or use Raspberry Pi Imager).
#
# If you don't use dhcpProxy, configure your router/DHCP to send:
# - Option 66 (next-server) = this host's IP
# - Option 67 (boot file) = filename or URL (Pi 5 may use HTTP; 67 can be a path)
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.piNetbootServer;
in
{
  options.piNetbootServer = {
    enable = lib.mkEnableOption "Serve Pi netboot image over HTTP (and optional DHCP proxy)";

    serveDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pi-netboot";
      description = "Directory to serve over HTTP; place the netboot image here.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "HTTP port for serving the image.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address to bind the HTTP server.";
    };

    # Optional: advertise this host as PXE/network boot server so Pis get next-server
    # without changing the main DHCP server. Uses dnsmasq in proxy mode.
    dhcpProxy = {
      enable = lib.mkEnableOption "DHCP proxy (dnsmasq) to advertise boot server to netbooting Pis";
      interface = lib.mkOption {
        type = lib.types.str;
        description = "Network interface for DHCP proxy (e.g. the LAN interface).";
        example = "eth0";
      };
      proxyNets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "10.0.0.0" "10.13.12.0" ];
        description = "Networks to proxy (dhcp-range=...,proxy). One entry per subnet.";
        example = [ "192.168.1.0" ];
      };
      bootServerIp = lib.mkOption {
        type = lib.types.str;
        description = "IP of this host (next-server / option 66). Use the LAN IP Pis can reach.";
        example = "10.13.12.101";
      };
      bootFilename = lib.mkOption {
        type = lib.types.str;
        description = "Boot file name or path sent as option 67 (e.g. filename or HTTP path).";
        example = "nixos-image-rpi5-kernel.img";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.serveDir} 0755 root root -"
    ];

    services.nginx = {
      enable = true;
      recommendedOptimisation = true;
      virtualHosts."pi-netboot" = {
        listen = [
          { addr = cfg.listenAddress; port = cfg.port; }
        ];
        root = cfg.serveDir;
        locations."/" = {
          extraConfig = ''
            autoindex on;
            autoindex_exact_size off;
            # Allow large file downloads (e.g. multi-GB images)
            chunked_transfer_encoding on;
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Optional DHCP proxy: respond to PXE clients with next-server + boot file
    # without taking over IP assignment. Requires firewall UDP 67.
    services.dnsmasq = lib.mkIf cfg.dhcpProxy.enable {
      enable = true;
      resolveLocalQueries = false; # Don't touch DNS; we only do DHCP proxy
      settings = {
        port = 0; # Disable DNS
        interface = cfg.dhcpProxy.interface;
        bind-dynamic = true; # Retry binding if interface isn't ready yet
        # Proxy DHCP: do not assign IPs, only send boot info (one range per subnet)
        dhcp-range = map (net: "${net},proxy") cfg.dhcpProxy.proxyNets;
        # Next server (option 66) = bootServerIp; boot file (67) = bootFilename
        # Format: dhcp-boot=filename,,serverip
        dhcp-boot = "${cfg.dhcpProxy.bootFilename},,${cfg.dhcpProxy.bootServerIp}";
        # Log for debugging
        log-dhcp = true;
        log-queries = false;
      };
    };

    # Ensure dnsmasq starts after the interface is available
    systemd.services.dnsmasq = lib.mkIf cfg.dhcpProxy.enable {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    networking.firewall.allowedUDPPorts = lib.mkIf cfg.dhcpProxy.enable [ 67 ];
  };
}

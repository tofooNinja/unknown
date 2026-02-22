{ config, lib, pkgs, ... }:

let
  cfg = config.custom.services.k3s;
in
{
  imports = [
    ./manifests.nix
  ];

  options.custom.services.k3s = {
    enable = lib.mkEnableOption "k3s cluster service";

    role = lib.mkOption {
      type = lib.types.enum [ "server" "agent" ];
      default = "server";
      description = "Role of this node in the k3s cluster.";
    };

    clusterInit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this server node should initialize a new cluster.";
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The URL of the k3s server (e.g., https://pix0:6443) to join. Required for agents or secondary servers.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to the secret containing the k3s cluster token.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      enable = true;
      role = cfg.role;
      clusterInit = cfg.clusterInit && cfg.role == "server";
      serverAddr = if cfg.serverUrl != "" && !(cfg.clusterInit && cfg.role == "server") then cfg.serverUrl else "";
      tokenFile = if cfg.tokenFile != "" then cfg.tokenFile else null;

      extraFlags = toString (
        # General flags
        [
          "--flannel-backend=host-gw"
        ]
        ++
        # Server-specific flags
        lib.optionals (cfg.role == "server") [
          "--disable=servicelb"
          "--disable=local-storage"
          # We might want to disable traefik if user wants to manage it via Helm specifically, 
          # but for now let's keep it or disable it if they want full Helm control.
          # "--disable=traefik" 
        ]
      );
    };

    # K3s requires cgroups to be enabled, which is especially important on Pis
    boot.kernelParams = [
      "cgroup_enable=cpuset"
      "cgroup_enable=memory"
      "cgroup_memory=1"
    ];

    # Open firewall for k3s
    networking.firewall.allowedTCPPorts = (if cfg.role == "server" then [ 6443 ] else [ ]) ++ [ 10250 ];
    networking.firewall.allowedUDPPorts = [ 8472 ]; # vxlan

    # Ensure required packages exist
    environment.systemPackages = with pkgs; [
      k3s
      kubernetes-helm
    ] ++ lib.optionals (cfg.role == "server") [
      kubectl
    ];

  };
}

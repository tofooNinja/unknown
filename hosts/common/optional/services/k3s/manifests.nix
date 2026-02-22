{ config, lib, pkgs, ... }:

let
  cfg = config.custom.services.k3s;

  # Helper to write HelmController HelmChart resources to the auto-deploy directory
  mkHelmChartManifest = name: chartUrl: chartName: chartVersion: values: targetNamespace:
    let
      chartYaml = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChart";
        metadata = {
          name = name;
          namespace = "kube-system";
        };
        spec = {
          repo = chartUrl;
          chart = chartName;
          version = chartVersion;
          targetNamespace = targetNamespace;
          createNamespace = true;
          valuesContent = builtins.toJSON values;
        };
      };
    in
    pkgs.writeText "${name}-chart.yaml" (builtins.toJSON chartYaml);

in
{
  options.custom.services.k3s.manifests = {
    enable = lib.mkEnableOption "installation of default helm charts via K3s built-in HelmController";
  };

  config = lib.mkIf (cfg.enable && cfg.role == "server" && cfg.manifests.enable) {
    # Place configured manifests into K3s' auto-deploy directory
    # Using environment.etc to place files in /var/lib/rancher/k3s/server/manifests is tricky because k3s expects real files there.
    # However, k3s follows symlinks in that directory.

    systemd.tmpfiles.rules = [
      "d /var/lib/rancher/k3s/server/manifests 0700 root root -"
      # Boilerplate Example: Traefik configuration or custom tools
      # "L+ /var/lib/rancher/k3s/server/manifests/traefik-config.yaml - - - - ${mkHelmChartManifest "traefik" "https://helm.traefik.io/traefik" "traefik" "25.0.0" {
      #   additionalArguments = [ "--log.level=INFO" ];
      # } "kube-system"}"
    ];
  };
}

# User-level sops configuration for home-manager
{
  inputs,
  config,
  hostSpec,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = "${builtins.toString inputs.nix-secrets}/sops/shared.yaml";

    age = {
      keyFile = "${hostSpec.home}/.config/sops/age/keys.txt";
    };
  };
}

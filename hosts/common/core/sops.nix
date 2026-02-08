# Host-level sops configuration
# User-level sops is in home/common/optional/sops.nix
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  secretsPath = builtins.toString inputs.nix-secrets;
  sopsFolder = "${secretsPath}/sops";
  # Fall back to shared.yaml if no per-host file exists
  hostSecretsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
  sharedSecretsFile = "${sopsFolder}/shared.yaml";
in
{
  sops = {
    defaultSopsFile = sharedSecretsFile;
    validateSopsFiles = false;

    age = {
      # Automatically import host SSH keys as age keys
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };

  # Bootstrap the user age key from host-level secrets
  # This allows home-manager sops to work without manual key copying
  sops.secrets = lib.mkMerge [
    {
      "keys/age" = {
        sopsFile = sharedSecretsFile;
        owner = config.users.users.${config.hostSpec.primaryUsername}.name;
        group = config.users.users.${config.hostSpec.primaryUsername}.group;
        path = "${config.hostSpec.home}/.config/sops/age/keys.txt";
      };
    }

    # User passwords
    (lib.mergeAttrsList (
      map (user: {
        "passwords/${user}" = {
          sopsFile = sharedSecretsFile;
          neededForUsers = true;
        };
      }) config.hostSpec.users
    ))
  ];

  # Fix ownership of .config/sops/age directory
  system.activationScripts.sopsSetAgeKeyOwnership =
    let
      ageFolder = "${config.hostSpec.home}/.config/sops/age";
      user = config.users.users.${config.hostSpec.primaryUsername}.name;
      group = config.users.users.${config.hostSpec.primaryUsername}.group;
    in
    ''
      mkdir -p ${ageFolder} || true
      chown -R ${user}:${group} ${config.hostSpec.home}/.config
    '';
}

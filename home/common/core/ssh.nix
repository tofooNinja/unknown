# User-level SSH configuration
{ inputs, lib, hostSpec, ... }:
let
  sshDir = "${hostSpec.home}/.ssh";
  sopsFile = "${builtins.toString inputs.nix-secrets}/sops/shared.yaml";
  keyRepoDir = lib.custom.relativeToRoot "hosts/common/users/tofoo/keys";

  managedPrivateKeyNames = [
    "id_ed25519_github"
    "id_ed25519_sk_github"
    "id_ed25519_pis"
    "id_ed25519_sk_pis"
    "id_ed25519_gitlab"
    "id_ed25519_sk_gitlab"
    "id_ed25519_home_server"
    "id_ed25519_sk_home_server"
  ];

  mkPrivateKeySecret =
    keyName:
    lib.nameValuePair "keys/ssh/${keyName}" {
      inherit sopsFile;
      path = "${sshDir}/${keyName}";
      mode = "0600";
    };

  managedPrivateKeySecrets = builtins.listToAttrs (map mkPrivateKeySecret managedPrivateKeyNames);

  mkManagedPubKey =
    keyName:
    lib.optionalAttrs (builtins.pathExists "${keyRepoDir}/${keyName}.pub") {
      ".ssh/${keyName}.pub".source = "${keyRepoDir}/${keyName}.pub";
    };
in
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = sopsFile;
    age.keyFile = "${hostSpec.home}/.config/sops/age/keys.txt";
    secrets = managedPrivateKeySecrets;
  };

  programs.ssh = {
    enable = true;
    # Keep SSH config fully explicit as Home Manager removes implicit defaults.
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        # Avoid offering unrelated keys to every host.
        identitiesOnly = true;
        # Store decrypted key material in the running agent for the login session.
        addKeysToAgent = "yes";
        # Reuse connections: one YubiKey touch opens a persistent socket,
        # subsequent sessions to the same host piggyback without a touch.
        # Useful: ssh -O exit <host>  (tear down stale master)
        #         ssh -o ControlMaster=no <host>  (bypass for debugging)
        extraOptions = {
          ControlMaster = "auto";
          ControlPath = "~/.ssh/sockets/%r@%h-%p";
          ControlPersist = "2h";
        };
      };

      "github.com" = {
        user = "git";
        identitiesOnly = true;
        identityFile = [
          "~/.ssh/id_ed25519_sk_github"
          "~/.ssh/id_ed25519_github"
        ];
      };

      "gitlab.com" = {
        user = "git";
        identitiesOnly = true;
        identityFile = [
          "~/.ssh/id_ed25519_sk_gitlab"
          "~/.ssh/id_ed25519_gitlab"
        ];
      };

      "pix0" = {
        hostname = "10.13.12.110";
        identitiesOnly = true;
        identityFile = [
          "~/.ssh/id_ed25519_sk_pis"
          "~/.ssh/id_ed25519_pis"
        ];
      };

      "pix1" = {
        hostname = "10.13.12.111";
        identitiesOnly = true;
        identityFile = [
          "~/.ssh/id_ed25519_sk_pis"
          "~/.ssh/id_ed25519_pis"
        ];
      };

      "px* pis* pix*" = {
        identitiesOnly = true;
        identityFile = [
          "~/.ssh/id_ed25519_sk_pis"
          "~/.ssh/id_ed25519_pis"
        ];
      };

      "home_server" = {
        hostname = "10.13.12.23";
        identitiesOnly = true;
        identityFile = [
          "~/.ssh/id_ed25519_sk_home_server"
          "~/.ssh/id_ed25519_home_server"
        ];
      };

      # Fallback for all other hosts: shared no-passphrase key.
      "* !px* !pis* !pix* !github.com !gitlab.com !home_server" = {
        identitiesOnly = true;
        identityFile = [ "~/.ssh/tofoo_all_no_pw" ];
      };
    };
  };

  # Start SSH agent to cache keys and avoid repeated passphrase prompts
  services.ssh-agent.enable = true;

  home.file = { ".ssh/sockets/.keep".text = ""; }
    // (mkManagedPubKey "id_ed25519_github")
    // (mkManagedPubKey "id_ed25519_sk_github")
    // (mkManagedPubKey "id_ed25519_pis")
    // (mkManagedPubKey "id_ed25519_sk_pis")
    // (mkManagedPubKey "id_ed25519_gitlab")
    // (mkManagedPubKey "id_ed25519_sk_gitlab")
    // (mkManagedPubKey "id_ed25519_home_server")
    // (mkManagedPubKey "id_ed25519_sk_home_server")
    // (mkManagedPubKey "tofoo_all_no_pw");
}

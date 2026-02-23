# SSH configuration
{ inputs, config, lib, ... }:
let
  sopsFile = "${builtins.toString inputs.nix-secrets}/sops/shared.yaml";
  rootSshDir = "/root/.ssh";
in
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password"; # Allow root login with SSH keys only
      PasswordAuthentication = false;
      # Some clients (e.g. ghostty) send TERM values not present on minimal hosts.
      # Force a broadly available terminfo entry at SSH session start.
      SetEnv = "TERM=xterm-256color";
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  # Root SSH client config — same as tofoo's but without GitHub/GitLab.
  # Needed for nix remote builders (daemon runs as root).
  programs.ssh = {
    extraConfig = ''
      Host *
        IdentitiesOnly yes
        AddKeysToAgent yes

      Host pix0
        Hostname 10.13.12.110
        IdentitiesOnly yes
        IdentityFile ${rootSshDir}/id_ed25519_sk_pis
        IdentityFile ${rootSshDir}/id_ed25519_pis

      Host pix1
        Hostname 10.13.12.111
        IdentitiesOnly yes
        IdentityFile ${rootSshDir}/id_ed25519_sk_pis
        IdentityFile ${rootSshDir}/id_ed25519_pis

      Host px* pis* pix*
        IdentitiesOnly yes
        IdentityFile ${rootSshDir}/id_ed25519_sk_pis
        IdentityFile ${rootSshDir}/id_ed25519_pis

      Host home_server
        Hostname 10.13.12.23
        IdentitiesOnly yes
        IdentityFile ${rootSshDir}/id_ed25519_sk_home_server
        IdentityFile ${rootSshDir}/id_ed25519_home_server

      Host * !px* !pis* !pix* !home_server
        IdentitiesOnly yes
        IdentityFile ${rootSshDir}/tofoo_all_no_pw
    '';
  };

  # Deploy root's SSH private keys via sops-nix
  sops.secrets = lib.mkIf config.hostSpec.enableSops {
    "keys/ssh/id_ed25519_pis" = {
      inherit sopsFile;
      path = "${rootSshDir}/id_ed25519_pis";
      owner = "root";
      mode = "0600";
    };
    "keys/ssh/id_ed25519_sk_pis" = {
      inherit sopsFile;
      path = "${rootSshDir}/id_ed25519_sk_pis";
      owner = "root";
      mode = "0600";
    };
    "keys/ssh/id_ed25519_home_server" = {
      inherit sopsFile;
      path = "${rootSshDir}/id_ed25519_home_server";
      owner = "root";
      mode = "0600";
    };
    "keys/ssh/id_ed25519_sk_home_server" = {
      inherit sopsFile;
      path = "${rootSshDir}/id_ed25519_sk_home_server";
      owner = "root";
      mode = "0600";
    };
    "keys/ssh-tofoo-all-no-pw-root" = {
      sopsFile = sopsFile;
      key = "keys/ssh-tofoo-all-no-pw";
      path = "${rootSshDir}/tofoo_all_no_pw";
      owner = "root";
      mode = "0600";
    };
  };

  # Some first-boot install flows (e.g. nixos-anywhere --extra-files) can land
  # host private keys with permissive modes. OpenSSH rejects those keys.
  system.activationScripts.fixSshHostKeyPerms.text = ''
    for key in /etc/ssh/ssh_host_*_key; do
      [ -f "$key" ] || continue
      chown root:root "$key"
      chmod 600 "$key"
    done

    for pub in /etc/ssh/ssh_host_*_key.pub; do
      [ -f "$pub" ] || continue
      chown root:root "$pub"
      chmod 644 "$pub"
    done
  '';
}

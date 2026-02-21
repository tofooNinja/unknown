# SSH configuration
{ config, lib, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password"; # Allow root login with SSH keys only
      PasswordAuthentication = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

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

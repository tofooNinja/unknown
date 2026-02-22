# YubiKey PAM U2F: local login and sudo with YubiKey as second factor
# Enable when hostSpec.useYubikey is true. Enroll with pamu2fcfg (see SECURITY-GUIDE.md).
{ config
, lib
, pkgs
, ...
}:
let
  home = config.hostSpec.home;
  u2fKeysPath = "${home}/.config/Yubico/u2f_keys";
in
lib.mkIf config.hostSpec.useYubikey {
  environment.systemPackages = [ pkgs.pam_u2f ];

  # udev rules so the YubiKey is recognized (FIDO/U2F)
  services.udev.packages = [ pkgs.yubikey-personalization ];

  security.pam = {
    u2f = {
      enable = true;
      control = "sufficient"; # YubiKey touch alone is enough; falls back to password
      settings = {
        cue = true; # Prompt user to touch the key
        authfile = u2fKeysPath;
        pinVerification = 0; # No PIN, touch-only
      };
    };
    services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
      # Graphical login (SDDM used by niri on space/black)
      sddm.u2fAuth = true;
    };
  };
}

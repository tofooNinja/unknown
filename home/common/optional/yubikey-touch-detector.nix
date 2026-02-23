# YubiKey touch notification — alerts when the key is waiting for a tap
{ pkgs, ... }:
{
  home.packages = [ pkgs.yubikey-touch-detector ];

  systemd.user.services.yubikey-touch-detector = {
    Unit = {
      Description = "YubiKey touch detector";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.yubikey-touch-detector}/bin/yubikey-touch-detector -libnotify";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}

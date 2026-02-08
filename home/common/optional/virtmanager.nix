# Virtual Machine Manager - dconf settings and extra packages
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    spice-gtk
    virtio-win
  ];

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
    "org/virt-manager/virt-manager" = {
      xmleditor-enabled = true;
      stats-update-interval = 1;
      console-accels = true;
    };
    "org/virt-manager/virt-manager/console" = {
      resize-guest = 1;
      scaling = 1;
    };
    "org/virt-manager/virt-manager/new-vm" = {
      graphics-type = "spice";
      cpu-default = "host-passthrough";
      storage-format = "qcow2";
    };
    "org/virt-manager/virt-manager/urls" = {
      isos = [ "/var/lib/libvirt/isos" ];
    };
  };
}

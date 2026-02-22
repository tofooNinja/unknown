# Raspberry Pi SSD dedicated to Longhorn storage (LUKS encrypted)
# Import alongside pi-sd-luks.nix for system-on-SD + storage-on-SSD layout
{ lib
, ssdDisk ? "/dev/nvme0n1"
, ...
}:
{
  disko.devices.disk = {
    longhorn = {
      type = "disk";
      device = ssdDisk;
      content = {
        type = "gpt";
        partitions = {
          longhorn = {
            size = "100%";
            label = "longhorn";
            content = {
              type = "luks";
              name = "crypted-longhorn";
              passwordFile = "/tmp/disko-password";
              settings.allowDiscards = true;
              extraFormatArgs = [ "--type" "luks2" ];
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/var/lib/longhorn";
                mountOptions = [ "noatime" "commit=60" ];
              };
            };
          };
        };
      };
    };
  };
}

# Raspberry Pi SD card disk layout with LUKS encryption
# FIRMWARE (1G) + ESP (1G) + encrypted swap + encrypted root
{ lib
, disk ? "/dev/mmcblk0"
, swapSize ? "8"
, ...
}:
{
  disko.devices.disk = {
    sd = {
      type = "disk";
      device = disk;
      content = {
        type = "gpt";
        partitions = {
          FIRMWARE = {
            priority = 1;
            type = "0700";
            attributes = [ 0 ];
            size = "1024M";
            label = "FIRMWARE";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot/firmware";
              mountOptions = [ "noatime" "noauto" "x-systemd.automount" ];
            };
          };

          ESP = {
            type = "EF00";
            attributes = [ 2 ];
            size = "1024M";
            label = "ESP";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "noatime" "umask=0077" ];
            };
          };

          encrypted_swap = {
            size = "${swapSize}G";
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };

          system = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              passwordFile = "/tmp/disko-password";
              settings.allowDiscards = true;
              extraFormatArgs = [ "--type" "luks2" ];
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "noatime" "commit=60" ];
              };
            };
          };
        };
      };
    };
  };
}

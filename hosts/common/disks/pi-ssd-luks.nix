# Raspberry Pi SSD (NVMe or USB) disk layout with LUKS encryption
# SD card still needed for FIRMWARE partition; root on SSD
{ lib
, sdDisk ? "/dev/mmcblk0"
, ssdDisk ? "/dev/nvme0n1"
, swapSize ? "8"
, ...
}:
{
  disko.devices.disk = {
    # SD card - firmware partition only
    sd = {
      type = "disk";
      device = sdDisk;
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
        };
      };
    };

    # SSD - ESP + swap + encrypted root
    ssd = {
      type = "disk";
      device = ssdDisk;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            type = "EF00";
            size = "1024M";
            label = "ESP";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "noatime" "noauto" "x-systemd.automount" "umask=0077" ];
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

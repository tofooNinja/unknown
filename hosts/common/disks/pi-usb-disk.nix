# Additional USB disk for Pis - LUKS encrypted
# Can be used for extra storage (HDDs/SSDs connected via USB)
{
  lib,
  disk ? "/dev/sda",
  name ? "usb-data",
  mountPoint ? "/data",
  fsType ? "ext4",
  ...
}:
{
  disko.devices.disk.${name} = {
    type = "disk";
    device = disk;
    content = {
      type = "gpt";
      partitions = {
        data = {
          size = "100%";
          content = {
            type = "luks";
            name = "${name}-crypt";
            passwordFile = "/tmp/${name}.key";
            settings.allowDiscards = true;
            extraFormatArgs = [ "--type" "luks2" ];
            content = {
              type = "filesystem";
              format = fsType;
              mountpoint = mountPoint;
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };
}

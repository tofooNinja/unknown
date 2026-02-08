# Optional module for adding encrypted USB disks to Pis
# Usage in host config:
#   piUsbDisks.disks = [
#     { device = "/dev/sda"; name = "hdd0"; mountPoint = "/data/hdd0"; }
#   ];
{
  config,
  lib,
  ...
}:
{
  options.piUsbDisks = {
    disks = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          device = lib.mkOption {
            type = lib.types.str;
            description = "Device path (e.g., /dev/sda)";
          };
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name for the disk (used in LUKS mapping)";
          };
          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Where to mount the disk";
          };
          fsType = lib.mkOption {
            type = lib.types.str;
            default = "ext4";
            description = "Filesystem type";
          };
        };
      });
      default = [ ];
      description = "List of additional USB disks to add with LUKS encryption";
    };
  };

  config = lib.mkIf (config.piUsbDisks.disks != [ ]) {
    # Each USB disk gets its own LUKS volume
    disko.devices.disk = lib.mergeAttrsList (
      map (d: {
        ${d.name} = {
          type = "disk";
          device = d.device;
          content = {
            type = "gpt";
            partitions = {
              data = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "${d.name}-crypt";
                  passwordFile = "/tmp/${d.name}.key";
                  settings.allowDiscards = true;
                  extraFormatArgs = [ "--type" "luks2" ];
                  content = {
                    type = "filesystem";
                    format = d.fsType;
                    mountpoint = d.mountPoint;
                    mountOptions = [ "noatime" ];
                  };
                };
              };
            };
          };
        };
      }) config.piUsbDisks.disks
    );
  };
}

# Common home-manager config for tofoo across all hosts
{
  lib,
  hostSpec,
  ...
}:
{
  imports = lib.flatten [
    (lib.custom.relativeToRoot "home/common/core")
    # Optional modules loaded conditionally
    (lib.optional (hostSpec.defaultDesktop == "niri")
      (lib.custom.relativeToRoot "home/common/optional/desktops/niri"))
    (lib.optional hostSpec.isGaming
      (lib.custom.relativeToRoot "home/common/optional/gaming.nix"))
  ];
}

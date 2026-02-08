# Common home-manager config for tofoo across all hosts
{ lib
, hostSpec
, ...
}:
{
  imports = lib.flatten [
    (lib.custom.relativeToRoot "home/common/core")
    # Optional desktop
    (lib.optional (hostSpec.defaultDesktop == "niri")
      (lib.custom.relativeToRoot "home/common/optional/desktops/niri"))
    (lib.optional hostSpec.isGaming
      (lib.custom.relativeToRoot "home/common/optional/gaming.nix"))
    # Optional GUI apps (when not a server)
    (lib.optionals (!hostSpec.isServer) [
      (lib.custom.relativeToRoot "home/common/optional/xdg.nix")
      (lib.custom.relativeToRoot "home/common/optional/swappy.nix")
      (lib.custom.relativeToRoot "home/common/optional/vscode.nix")
      (lib.custom.relativeToRoot "home/common/optional/virtmanager.nix")
    ])
  ];
}

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
    (lib.optional (hostSpec.barChoice == "noctalia")
      (lib.custom.relativeToRoot "home/common/optional/noctalia-shell"))
    (lib.optional hostSpec.isGaming
      (lib.custom.relativeToRoot "home/common/optional/gaming.nix"))
    # Optional GUI apps (when not a server)
    (lib.optional (hostSpec.useStylix or false)
      (lib.custom.relativeToRoot "home/common/optional/stylix.nix"))
    (lib.optionals (!hostSpec.isServer) [
      (lib.custom.relativeToRoot "home/common/optional/xdg.nix")
      (lib.custom.relativeToRoot "home/common/optional/swappy.nix")
      (lib.custom.relativeToRoot "home/common/optional/vscode.nix")
      (lib.custom.relativeToRoot "home/common/optional/virtmanager.nix")
      (lib.custom.relativeToRoot "home/common/optional/wlogout")
      (lib.custom.relativeToRoot "home/common/optional/nwg-drawer.nix")
      (lib.custom.relativeToRoot "home/common/optional/i3.nix")
      # Standalone GTK/Qt only when not using Niri (Niri has its own)
      (lib.optional (hostSpec.defaultDesktop != "niri")
        (lib.custom.relativeToRoot "home/common/optional/gtk.nix"))
      (lib.optional (hostSpec.defaultDesktop != "niri")
        (lib.custom.relativeToRoot "home/common/optional/qt.nix"))
    ])
  ];
}

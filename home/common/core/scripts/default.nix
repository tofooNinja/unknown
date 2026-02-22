# Custom scripts (wallsetter, webapp-install, hm-find, etc.)
{ pkgs, lib, hostSpec, ... }:
{
  home.packages = [
    (import ./hm-find.nix { inherit pkgs; })
  ] ++ lib.optionals (!hostSpec.isPi) [
    (import ./wallsetter.nix { inherit pkgs; })
    (import ./webapp-install.nix { inherit pkgs; })
    (import ./webapp-remove.nix { inherit pkgs; })
    (import ./screenshootin.nix { inherit pkgs; })
    (import ./emopicker9000.nix { inherit pkgs; })
  ];
}

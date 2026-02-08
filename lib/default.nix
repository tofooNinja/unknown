{ lib, ... }:
{
  # Use path relative to the root of this project
  relativeToRoot = lib.path.append ../.;

  # Scan a directory for .nix files and subdirectories with default.nix
  scanPaths =
    path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
          (_type == "directory") # include directories (expecting default.nix)
          || (
            (path != "default.nix") # exclude default.nix
            && (lib.strings.hasSuffix ".nix" path) # include .nix files
          )
        ) (builtins.readDir path)
      )
    );
}

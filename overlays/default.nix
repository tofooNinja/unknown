{ inputs, lib, ... }:
{
  snapmaker-orca-slicer = final: prev: {
    snapmaker-orca-slicer = prev.orca-slicer.overrideAttrs (oldAttrs: {
      pname = "snapmaker-orca-slicer";
      version = "2.2.4";
      src = final.fetchFromGitHub {
        owner = "Snapmaker";
        repo = "OrcaSlicer";
        tag = "v2.2.4";
        hash = "sha256-qK4etfhgha0etcKT9f0og9SI9mTs9G/qaG/jl+44qo8=";
      };
      patches = [ ];
    });
  };
}

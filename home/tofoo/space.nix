# Host-specific home config for space
{ pkgs
, hostSpec
, ...
}:
{
  home.packages = [ pkgs.snapmaker-orca-slicer ];
}

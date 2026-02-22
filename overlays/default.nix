{ inputs, lib, ... }:
{
  snapmaker-orca-slicer = final: prev: {
    # Source build fix for C23 'bool' error
    snapmaker-orca-slicer-src = prev.orca-slicer.overrideAttrs (oldAttrs: {
      pname = "snapmaker-orca-slicer-src";
      version = "2.2.4";
      src = final.fetchFromGitHub {
        owner = "Snapmaker";
        repo = "OrcaSlicer";
        tag = "v2.2.4";
        hash = "sha256-qK4etfhgha0etcKT9f0og9SI9mTs9G/qaG/jl+44qo8=";
      };
      # Fix C23 bool error in bundled paho-mqtt-c
      postPatch = (oldAttrs.postPatch or "") + ''
        sed -i 's/typedef unsigned int bool;/\/\* typedef unsigned int bool; \*\//' src/mqtt/externals/paho-mqtt-c/src/MQTTPacket.h
      '';
      patches = [ ];
    });

    # AppImage version (Alternative "different way")
    snapmaker-orca-slicer-bin = final.appimageTools.wrapType2 {
      pname = "snapmaker-orca-slicer";
      version = "2.2.4";
      src = final.fetchurl {
        url = "https://github.com/Snapmaker/OrcaSlicer/releases/download/v2.2.4/Snapmaker_Orca_Linux_AppImage_Ubuntu2404_V2.2.4_Beta.AppImage";
        hash = "sha256-eX1VYiMSW7sF6c9uKsLu9phpPIuQHlk3EzFxcohHZx4=";
      };
      extraPkgs = pkgs: with pkgs; [
        webkitgtk_4_1
        libsecret
      ];
    };

    # Switched to binary version for better reliability on failing source builds
    snapmaker-orca-slicer = final.snapmaker-orca-slicer-bin;
  };
}

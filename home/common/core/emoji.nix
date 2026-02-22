# Emoji picker data (desktop only)
{ hostSpec, lib, ... }:
lib.mkIf (!hostSpec.isServer) {
  home.file.".config/.emoji".text = builtins.readFile ./emoji-data.txt;
}

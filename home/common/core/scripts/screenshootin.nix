# Screenshot region with grim/slurp, save and copy to clipboard
{ pkgs, ... }:
pkgs.writeShellScriptBin "screenshootin" ''
  mkdir -p "$HOME/Pictures/Screenshots"
  filename="$HOME/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png"
  ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$filename" && ${pkgs.wl-clipboard}/bin/wl-copy < "$filename"
''

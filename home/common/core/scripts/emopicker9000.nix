# Emoji picker using fuzzel and .config/.emoji
{ pkgs, ... }:
pkgs.writeShellScriptBin "emopicker9000" ''
  [ -f "$HOME/.config/.emoji" ] || { echo "No .config/.emoji found"; exit 1; }
  chosen=$(cat "$HOME/.config/.emoji" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --width 60 --lines 20 | awk '{print $1}')
  [ -z "$chosen" ] && exit
  if [ -n "$1" ]; then
    ${pkgs.ydotool}/bin/ydotool type "$chosen"
  else
    printf "%s" "$chosen" | ${pkgs.wl-clipboard}/bin/wl-copy
    ${pkgs.libnotify}/bin/notify-send "'$chosen' copied to clipboard." &
  fi
''

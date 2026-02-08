# Wallpaper rotator using swww
{ pkgs, ... }:
pkgs.writeShellScriptBin "wallsetter" ''
  TIMEOUT=720

  for pid in $(pidof -o %PPID -x wallsetter 2>/dev/null); do
    kill $pid 2>/dev/null || true
  done

  if ! [ -d "$HOME/Pictures/Wallpapers" ]; then
    notify-send -t 5000 "~/Pictures/Wallpapers does not exist"
    exit 1
  fi
  if [ $(ls -1 "$HOME/Pictures/Wallpapers" 2>/dev/null | wc -l) -lt 1 ]; then
    notify-send -t 9000 "The wallpaper folder is expected to have more than 1 image. Exiting Wallsetter."
    exit 1
  fi

  PREVIOUS=""
  while true; do
    WALLPAPER="$PREVIOUS"
    while [ "$WALLPAPER" = "$PREVIOUS" ]; do
      WALLPAPER=$(find "$HOME/Pictures/Wallpapers" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null | shuf -n 1)
    done
    PREVIOUS="$WALLPAPER"
    ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type random --transition-step 1 --transition-fps 60
    sleep $TIMEOUT
  done
''

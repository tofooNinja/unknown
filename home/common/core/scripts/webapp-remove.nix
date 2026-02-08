# Remove installed web apps
{ pkgs, ... }:
pkgs.writeShellScriptBin "webapp-remove" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  list_webapps() {
    echo "Installed webapps:"
    for desktop in "$HOME/.local/share/applications"/*.desktop 2>/dev/null; do
      [ -f "$desktop" ] || continue
      grep -q "Categories=.*WebApp" "$desktop" 2>/dev/null || continue
      name=$(basename "$desktop" .desktop)
      echo "  • $name"
    done
  }

  remove_webapp() {
    local app_name="$1"
    local desktop_file="$HOME/.local/share/applications/$app_name.desktop"
    local icon_name=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local icon_file="$HOME/.local/share/icons/hicolor/256x256/apps/$icon_name.png"

    [ -f "$desktop_file" ] || { echo "Error: Webapp '$app_name' not found" >&2; list_webapps >&2; return 1; }
    rm -f "$desktop_file" "$icon_file"
    ${pkgs.gtk3}/bin/gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    echo "✓ Removed: $app_name"
  }

  if [ "$#" -eq 1 ]; then
    case "$1" in
      --help|-h) echo "Usage: webapp-remove [APP_NAME] or no args to choose"; exit 0 ;;
      --list|-l) list_webapps; exit 0 ;;
      *) remove_webapp "$1"; exit 0 ;;
    esac
  fi

  if [ "$#" -eq 0 ]; then
    webapps=()
    for desktop in "$HOME/.local/share/applications"/*.desktop 2>/dev/null; do
      [ -f "$desktop" ] && grep -q "Categories=.*WebApp" "$desktop" 2>/dev/null && webapps+=("$(basename "$desktop" .desktop)")
    done
    [ ''${#webapps[@]} -eq 0 ] && { echo "No webapps found."; exit 0; }
    selected=$(printf '%s\n' "''${webapps[@]}" | ${pkgs.gum}/bin/gum choose --header "Select webapp to remove:")
    [ -n "$selected" ] && remove_webapp "$selected"
  else
    echo "Usage: webapp-remove [APP_NAME]"; exit 1
  fi
''

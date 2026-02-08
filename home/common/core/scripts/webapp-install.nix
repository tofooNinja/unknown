# Web app installer - creates .desktop entries for PWAs
{ pkgs, ... }:
pkgs.writeShellScriptBin "webapp-install" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    VERSION="1.0.0"

    print_help() {
      echo "Web App Installer -- version $VERSION"
      echo "Usage: webapp-install [OPTIONS] [APP_NAME URL ICON_REF]"
      echo "  webapp-install                    # interactive"
      echo "  webapp-install \"Name\" \"https://...\" \"https://icon.png\""
      echo "Options: --help, -h"
    }

    if [ "$#" -eq 1 ] && [[ "$1" == "--help" || "$1" == "-h" ]]; then
      print_help
      exit 0
    fi

    if [ "$#" -lt 3 ]; then
      APP_NAME=$(${pkgs.gum}/bin/gum input --prompt "Name> " --placeholder "My web app")
      APP_URL=$(${pkgs.gum}/bin/gum input --prompt "URL> " --placeholder "https://example.com")
      ICON_REF=$(${pkgs.gum}/bin/gum input --prompt "Icon URL> " --placeholder "https://... (PNG)")
      CUSTOM_EXEC=""
      MIME_TYPES=""
      INTERACTIVE_MODE=true
    else
      APP_NAME="$1"
      APP_URL="$2"
      ICON_REF="$3"
      CUSTOM_EXEC="''${4:-}"
      MIME_TYPES="''${5:-}"
      INTERACTIVE_MODE=false
    fi

    [[ -n "$APP_NAME" && -n "$APP_URL" && -n "$ICON_REF" ]] || { echo "Error: Set app name, URL and icon URL!" >&2; exit 1; }

    ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
    mkdir -p "$ICON_DIR"
    ICON_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    if [[ $ICON_REF =~ ^https?:// ]]; then
      ICON_FILE="$ICON_DIR/$ICON_NAME.png"
      ${pkgs.curl}/bin/curl -sL -o "$ICON_FILE" "$ICON_REF" || { echo "Error: Failed to download icon." >&2; exit 1; }
    else
      ICON_FILE="$ICON_DIR/$ICON_NAME.png"
      cp "$ICON_REF" "$ICON_FILE" 2>/dev/null || true
    fi

    if [[ -n $CUSTOM_EXEC ]]; then
      EXEC_COMMAND="$CUSTOM_EXEC"
    else
      EXEC_COMMAND="${pkgs.chromium}/bin/chromium --app=\"$APP_URL\""
    fi

    DESKTOP_FILE="$HOME/.local/share/applications/$APP_NAME.desktop"
    cat >"$DESKTOP_FILE" <<EOF
  [Desktop Entry]
  Version=1.0
  Name=$APP_NAME
  Comment=$APP_NAME
  Exec=$EXEC_COMMAND
  Terminal=false
  Type=Application
  Icon=$ICON_FILE
  StartupNotify=true
  Categories=WebApp;Network;
  EOF
    [[ -n $MIME_TYPES ]] && echo "MimeType=$MIME_TYPES" >>"$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    ${pkgs.gtk3}/bin/gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    echo "✓ Web app created: $DESKTOP_FILE"
    [[ $INTERACTIVE_MODE == true ]] && echo "Find it in your app launcher (e.g. SUPER + SPACE)."
''

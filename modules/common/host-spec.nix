# Host specifications for differentiating hosts
{ config
, pkgs
, lib
, ...
}:
{
  options.hostSpec = lib.mkOption {
    type = lib.types.submodule {
      options = {
        # ── Identity ────────────────────────────────────────────────
        hostName = lib.mkOption {
          type = lib.types.str;
          description = "The hostname of this machine";
        };
        primaryUsername = lib.mkOption {
          type = lib.types.str;
          default = "tofoo";
          description = "The primary administrative username";
        };
        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ config.hostSpec.primaryUsername ];
          description = "All users on this host";
        };
        home = lib.mkOption {
          type = lib.types.str;
          default = "/home/${config.hostSpec.primaryUsername}";
          description = "Home directory of the primary user";
        };
        userFullName = lib.mkOption {
          type = lib.types.str;
          default = "tofoo";
          description = "Full name of the primary user";
        };
        email = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Email addresses";
        };
        domain = lib.mkOption {
          type = lib.types.str;
          default = "local";
          description = "The domain of this host";
        };
        networking = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Networking information";
        };

        # ── Host Classification ─────────────────────────────────────
        isServer = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this is a server host";
        };
        isRoaming = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this is a roaming/laptop host";
        };
        isDevelopment = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host is used for development";
        };
        isBuildServer = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host acts as a nix build server";
        };
        isGaming = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host is used for gaming";
        };
        isClusterNode = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host participates in the k3s cluster";
        };
        enableSops = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether host-level sops secret deployment is enabled";
        };

        # ── Hardware ────────────────────────────────────────────────
        useYubikey = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host uses a YubiKey";
        };
        wifi = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host has WiFi";
        };

        # ── Pi-specific ─────────────────────────────────────────────
        isPi = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host is a Raspberry Pi";
        };
        piModel = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "pi4" "pi5" ]);
          default = null;
          description = "Raspberry Pi model (pi4 or pi5)";
        };
        bootMedia = lib.mkOption {
          type = lib.types.enum [ "sd" "nvme" "usb" ];
          default = "sd";
          description = "Boot media type for Pis";
        };
        hasTpm = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this Pi has a TPM module";
        };
        isHomeMedia = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this Pi is a home media/retro console device";
        };

        # ── Desktop / Display ───────────────────────────────────────
        useWayland = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this host uses Wayland";
        };
        useX11 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host uses X11";
        };
        defaultDesktop = lib.mkOption {
          type = lib.types.str;
          default = "niri";
          description = "The default desktop/window manager";
        };
        defaultBrowser = lib.mkOption {
          type = lib.types.str;
          default = "zen";
          description = "Default browser";
        };
        defaultTerminal = lib.mkOption {
          type = lib.types.str;
          default = "ghostty";
          description = "Default terminal emulator";
        };
        barChoice = lib.mkOption {
          type = lib.types.str;
          default = "noctalia";
          description = "Bar/shell choice (noctalia, waybar, etc.)";
        };
        defaultShell = lib.mkOption {
          type = lib.types.str;
          default = "zsh";
          description = "Default shell (zsh or fish)";
        };

        # ── Feature Toggles ────────────────────────────────────────
        enableCommunicationApps = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable communication apps (Telegram, Vesktop, Signal)";
        };
        aiCodeEditorsEnable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable AI code editors (Cursor, Claude Code, Gemini CLI)";
        };

        # ── Theming ─────────────────────────────────────────────────
        useStylix = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host uses Stylix (system + home-manager theming)";
        };
        wallpaper = lib.mkOption {
          type = lib.types.path;
          default = ../../wallpapers/Valley.jpg;
          description = "Path to wallpaper";
        };
        timeZone = lib.mkOption {
          type = lib.types.str;
          default = "Europe/Berlin";
          description = "Timezone for this host";
        };
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.elem config.hostSpec.primaryUsername config.hostSpec.users;
        message = "primaryUsername '${config.hostSpec.primaryUsername}' must exist in list of users";
      }
    ];
  };
}

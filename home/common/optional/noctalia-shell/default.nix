# Noctalia Shell - desktop shell (bar, launcher, control center)
# Import when barChoice == "noctalia"
{ config
, lib
, pkgs
, inputs
, hostSpec
, ...
}:
let
  enableNoctalia = hostSpec.barChoice == "noctalia";
  homeDir = config.home.homeDirectory;
  terminal = hostSpec.defaultTerminal;
in
{
  imports = lib.optionals enableNoctalia [
    inputs.noctalia.homeModules.default
  ];

  config = lib.mkIf enableNoctalia {
    programs.waybar.enable = lib.mkForce false;
    home.packages = [ inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default ];

    home.file.".config/noctalia/settings.json.template" = {
      text = builtins.toJSON {
        appLauncher = {
          backgroundOpacity = 1;
          enableClipboardHistory = false;
          pinnedExecs = [ ];
          position = "center";
          sortByMostUsed = true;
          terminalCommand = "${terminal} -e";
          useApp2Unit = false;
        };
        audio = {
          cavaFrameRate = 60;
          mprisBlacklist = [ ];
          preferredPlayer = "";
          visualizerType = "linear";
          volumeOverdrive = false;
          volumeStep = 5;
        };
        bar = {
          backgroundOpacity = 1;
          density = "default";
          floating = false;
          marginHorizontal = 0.25;
          marginVertical = 0.25;
          monitors = [ ];
          position = "top";
          showCapsule = true;
          widgets = {
            center = [
              {
                customFont = "";
                formatHorizontal = "h:mm AP, MMM dd";
                formatVertical = "HH mm - dd MM";
                id = "Clock";
                useCustomFont = false;
                usePrimaryColor = true;
              }
            ];
            left = [
              { hideUnoccupied = false; id = "Workspace"; labelMode = "index"; }
              {
                colorizeIcons = false;
                hideMode = "hidden";
                id = "ActiveWindow";
                maxWidth = 145;
                scrollingMode = "hover";
                showIcon = true;
                useFixedWidth = false;
              }
              {
                hideMode = "hidden";
                id = "MediaMini";
                maxWidth = 145;
                scrollingMode = "hover";
                showAlbumArt = false;
                showVisualizer = false;
                useFixedWidth = false;
                visualizerType = "linear";
              }
            ];
            right = [
              { blacklist = [ ]; colorizeIcons = false; id = "Tray"; }
              {
                id = "SystemMonitor";
                showCpuTemp = true;
                showCpuUsage = true;
                showDiskUsage = false;
                showMemoryAsPercent = false;
                showMemoryUsage = true;
                showNetworkStats = false;
              }
              { hideWhenZero = true; id = "NotificationHistory"; showUnreadBadge = true; }
              { displayMode = "onhover"; id = "Volume"; }
              {
                customIconPath = "";
                icon = "noctalia";
                id = "ControlCenter";
                useDistroLogo = false;
              }
            ];
          };
        };
        battery = { chargingMode = 0; };
        brightness = { brightnessStep = 5; };
        colorSchemes = {
          darkMode = true;
          generateTemplatesForPredefined = true;
          manualSunrise = "06:30";
          manualSunset = "18:30";
          matugenSchemeType = "scheme-fruit-salad";
          predefinedScheme = "Catppuccin";
          schedulingMode = "off";
          useWallpaperColors = false;
        };
        controlCenter = {
          cards = map (id: { enabled = true; inherit id; }) [
            "profile-card"
            "shortcuts-card"
            "audio-card"
            "weather-card"
            "media-sysmon-card"
          ];
          position = "close_to_bar_button";
          shortcuts = {
            left = map (id: { inherit id; }) [ "WiFi" "Bluetooth" "ScreenRecorder" "WallpaperSelector" ];
            right = map (id: { inherit id; }) [ "Notifications" "PowerProfile" "KeepAwake" "NightLight" ];
          };
        };
        dock = {
          backgroundOpacity = 1;
          colorizeIcons = true;
          displayMode = "exclusive";
          floatingRatio = 1;
          monitors = [ ];
          onlySameOutput = true;
          pinnedApps = [ ];
          size = 1;
        };
        general = {
          animationDisabled = false;
          animationSpeed = 1;
          avatarImage = "";
          compactLockScreen = false;
          dimDesktop = true;
          forceBlackScreenCorners = false;
          language = "en";
          lockOnSuspend = true;
          radiusRatio = 0.5;
          scaleRatio = 1;
          screenRadiusRatio = 1;
          showScreenCorners = false;
        };
        hooks = { darkModeChange = ""; enabled = false; wallpaperChange = ""; };
        "location" = {
          name = "Local";
          showCalendarEvents = true;
          showWeekNumberInCalendar = false;
          use12hourFormat = false;
          useFahrenheit = false;
          weatherEnabled = true;
        };
        network = { wifiEnabled = true; };
        nightLight = {
          autoSchedule = true;
          dayTemp = "6500";
          enabled = false;
          forced = false;
          manualSunrise = "06:30";
          manualSunset = "18:30";
          nightTemp = "4000";
        };
        notifications = {
          criticalUrgencyDuration = 15;
          doNotDisturb = false;
          "location" = "top_right";
          lowUrgencyDuration = 3;
          monitors = [ ];
          normalUrgencyDuration = 8;
          overlayLayer = true;
          respectExpireTimeout = false;
        };
        osd = {
          autoHideMs = 2000;
          enabled = true;
          "location" = "top_right";
          monitors = [ ];
          overlayLayer = true;
        };
        screenRecorder = {
          audioCodec = "opus";
          audioSource = "default_output";
          colorRange = "limited";
          directory = "";
          frameRate = 60;
          quality = "very_high";
          showCursor = true;
          videoCodec = "h264";
          videoSource = "portal";
        };
        settingsVersion = 16;
        setupCompleted = true;
        templates = {
          discord = false;
          fuzzel = true;
          ghostty = true;
          gtk = false;
          kitty = false;
          qt = false;
          enableUserTemplates = false;
        };
        ui = {
          fontDefault = "Fira Code Nerd Font";
          fontDefaultScale = 1;
          fontFixed = "DejaVu Sans Mono";
          fontFixedScale = 1;
          panelsOverlayLayer = true;
          tooltipsEnabled = true;
        };
        wallpaper = {
          defaultWallpaper = "";
          directory = "";
          enableMultiMonitorDirectories = false;
          enabled = true;
          fillColor = "#000000";
          fillMode = "crop";
          monitors = [ ];
          randomEnabled = false;
          randomIntervalSec = 300;
          setWallpaperOnAllMonitors = true;
          transitionDuration = 1500;
          transitionEdgeSmoothness = 0.05;
          transitionType = "random";
        };
      };
    };

    home.activation.noctaliaSettingsInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      SETTINGS_FILE="$HOME/.config/noctalia/settings.json"
      TEMPLATE_FILE="$HOME/.config/noctalia/settings.json.template"
      if [ ! -f "$SETTINGS_FILE" ] || [ -L "$SETTINGS_FILE" ]; then
        $DRY_RUN_CMD rm -f "$SETTINGS_FILE"
        $DRY_RUN_CMD cp "$TEMPLATE_FILE" "$SETTINGS_FILE"
        $DRY_RUN_CMD chmod 644 "$SETTINGS_FILE"
      fi
    '';
  };
}

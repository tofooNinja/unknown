# XDG MIME default applications (browser for http/https)
{ config
, hostSpec
, ...
}:
let
  # Map hostSpec.defaultBrowser to .desktop file name
  browserDesktop =
    {
      brave = "brave-browser.desktop";
      zen = "zen-beta.desktop";
      firefox = "firefox.desktop";
      chromium = "chromium.desktop";
    }.${hostSpec.defaultBrowser}
      or "brave-browser.desktop";
in
{
  xdg.mimeApps.defaultApplications = {
    "text/html" = browserDesktop;
    "x-scheme-handler/http" = browserDesktop;
    "x-scheme-handler/https" = browserDesktop;
    "x-scheme-handler/about" = browserDesktop;
    "application/x-extension-htm" = browserDesktop;
    "application/x-extension-html" = browserDesktop;
    "application/x-extension-shtml" = browserDesktop;
    "application/xhtml+xml" = browserDesktop;
    "application/x-extension-xhtml" = browserDesktop;
    "application/x-extension-xht" = browserDesktop;
  };
}

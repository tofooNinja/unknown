# Qt theming
{ lib, ... }:
{
  qt = {
    enable = true;
    # Let Stylix manage the platform theme; only override if needed
    # platformTheme.name is set by stylix to "qtct"
  };
}

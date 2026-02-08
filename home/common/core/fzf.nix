# Fzf - fuzzy finder
{ config
, lib
, ...
}:
let
  colors =
    if config.lib ? stylix
    then config.lib.stylix.colors
    else {
      base0D = "0000ff";
      base05 = "ffffff";
      base03 = "888888";
    };
  accent = "#" + colors.base0D;
  foreground = "#" + colors.base05;
  muted = "#" + colors.base03;
in
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    colors = lib.mkForce {
      "fg+" = accent;
      "bg+" = "-1";
      "fg" = foreground;
      "bg" = "-1";
      "prompt" = muted;
      "pointer" = accent;
    };
    defaultOptions = [
      "--margin=1"
      "--layout=reverse"
      "--border=none"
      "--info='hidden'"
      "--header=''"
      "--prompt='--> '"
      "-i"
      "--no-bold"
      "--preview='bat --style=numbers --color=always --line-range :500 {}'"
      "--preview-window=right:60%:wrap"
    ];
  };
}

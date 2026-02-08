# Shell configuration - Zsh
{
  pkgs,
  ...
}:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      share = true;
    };

    shellAliases = {
      ll = "eza -la --icons --group-directories-first";
      ls = "eza --icons --group-directories-first";
      la = "eza -a --icons --group-directories-first";
      lt = "eza --tree --icons --group-directories-first";
      cat = "bat";
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    initExtra = ''
      # Key bindings
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward
      bindkey '^R' history-incremental-search-backward
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}

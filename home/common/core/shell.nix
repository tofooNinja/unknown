# Shell configuration - Zsh
{ config
, pkgs
, ...
}:
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
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

    # Aliases for eza/bat/cd are managed by eza.nix, bat.nix, bash.nix
    shellAliases = {
      sv = "sudo nvim";
      v = "nvim";
      c = "clear";
      ncg = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
    };

    initContent = ''
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

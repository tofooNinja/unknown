# Zsh configuration with Powerlevel10k and direnv
{ config
, pkgs
, lib
, hostSpec
, ...
}:
let
  defaultShell = hostSpec.defaultShell or "zsh";
in
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    defaultKeymap = "viins";
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = [
        "main"
        "brackets"
        "pattern"
        "regexp"
        "root"
        "line"
      ];
    };
    historySubstringSearch.enable = true;
    enableCompletion = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      share = true;
    };

    oh-my-zsh.enable = true;

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = lib.cleanSource ./p10k-config;
        file = "p10k.zsh";
      }
    ];

    initContent = ''
      # Keep SSH sessions usable on hosts missing custom terminfo entries.
      if [[ -n "$SSH_CONNECTION" ]]; then
        export TERM=xterm-256color
      fi

      ${lib.optionalString (defaultShell == "fish") ''
        if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]; then
          shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
          exec fish $LOGIN_OPTION
        fi
      ''}
      bindkey "\eh" backward-word
      bindkey "\ej" down-line-or-history
      bindkey "\ek" up-line-or-history
      bindkey "\el" forward-word
      if [ -f "$HOME/.zshrc-personal" ]; then
        source "$HOME/.zshrc-personal"
      fi
      if [[ -z "$FASTFETCH_LAUNCHED" ]]; then
        export FASTFETCH_LAUNCHED=1
        fastfetch
      fi
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward
      bindkey '^R' history-incremental-search-backward
    '';

    shellAliases = {
      sv = "sudo nvim";
      v = "nvim";
      c = "clear";
      ncg = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      man = "batman";
    };
  };

  home.packages = with pkgs; [ zsh-powerlevel10k fastfetch ];
  home.file.".zshrc-personal".text = "# Personal zsh overrides (aliases, functions)\n";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}

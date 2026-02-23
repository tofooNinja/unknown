# Bash shell configuration
{ ... }:
{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      if [ -f "$HOME/.bashrc-personal" ]; then
        source "$HOME/.bashrc-personal"
      fi
    '';
    shellAliases = {
      r = "ranger";
      sv = "sudo nvim";
      v = "nvim";
      ".." = "cd ..";
      "..." = "cd ../..";
      ncg = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
    };
  };
}

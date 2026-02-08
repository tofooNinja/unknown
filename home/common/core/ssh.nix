# User-level SSH configuration
{ lib, ... }:
{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        identityFile = "~/.ssh/id_sk_all";
      };
      "px*" = {
        identityFile = "~/.ssh/id_sk_pis";
      };
      "github.com gitlab.com" = {
        identityFile = "~/.ssh/id_sk_git";
      };
    };
  };

  # Start SSH agent to cache keys and avoid repeated passphrase prompts
  services.ssh-agent.enable = true;

  home.file = {
    ".ssh/id_y0.pub".source = lib.custom.relativeToRoot "hosts/common/users/tofoo/keys/id_y0.pub";
    ".ssh/tofoo_no_pw.pub".source = lib.custom.relativeToRoot "hosts/common/users/tofoo/keys/tofoo_no_pw.pub";
    ".ssh/tofoo_all_no_pw.pub".source = lib.custom.relativeToRoot "hosts/common/users/tofoo/keys/tofoo_all_no_pw.pub";
    ".ssh/id_sk_all.pub".source = lib.custom.relativeToRoot "hosts/common/users/tofoo/keys/id_sk_all.pub";
    ".ssh/id_sk_pis.pub".source = lib.custom.relativeToRoot "hosts/common/users/tofoo/keys/id_sk_pis.pub";
    ".ssh/id_sk_git.pub".source = lib.custom.relativeToRoot "hosts/common/users/tofoo/keys/id_sk_git.pub";
  };
}

# Git configuration
{
  hostSpec,
  ...
}:
{
  programs.git = {
    enable = true;
    userName = hostSpec.primaryUsername;
    userEmail = hostSpec.email.user or "tofoo@pm.me";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.autocrlf = "input";
      # GPG signing with YubiKey will be configured in the security guide
    };
    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };
  };
}

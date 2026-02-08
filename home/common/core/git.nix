# Git configuration
{
  hostSpec,
  ...
}:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = hostSpec.primaryUsername;
        email = hostSpec.email.user or "tofoo@pm.me";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.autocrlf = "input";
      # GPG signing with YubiKey will be configured in the security guide
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
    };
  };
}

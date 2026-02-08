# User management - creates users and sets up home-manager
{ inputs
, pkgs
, config
, lib
, secrets
, ...
}:
let
  inherit (config) hostSpec;

  # Generate list of public key contents for a user
  genPubKeyList =
    user:
    let
      keyPath = lib.custom.relativeToRoot "hosts/common/users/${user}/keys";
    in
    if (lib.pathExists keyPath) then
      lib.lists.forEach (lib.filesystem.listFilesRecursive keyPath) (key: lib.readFile key)
    else
      [ ];
in
{
  # ── System Users ────────────────────────────────────────────────
  users = {
    mutableUsers = false; # Passwords managed via sops
    users =
      (lib.mergeAttrsList (
        map
          (user: {
            "${user}" = {
              name = user;
              isNormalUser = true;
              shell = pkgs.zsh;
              extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
              openssh.authorizedKeys.keys = genPubKeyList user;
              home = "/home/${user}";
              hashedPasswordFile = config.sops.secrets."passwords/${user}".path;
            };
          })
          hostSpec.users
      ))
      // {
        root = {
          shell = pkgs.zsh;
          hashedPasswordFile = config.users.users.${hostSpec.primaryUsername}.hashedPasswordFile;
          openssh.authorizedKeys.keys =
            config.users.users.${hostSpec.primaryUsername}.openssh.authorizedKeys.keys;
        };
      };
  };

  # ── Home-Manager ────────────────────────────────────────────────
  home-manager = {
    extraSpecialArgs = {
      inherit inputs secrets;
      inherit (config) hostSpec;
    };
    users =
      (lib.mergeAttrsList (
        map
          (user:
            let
              fullPathIfExists =
                path:
                let
                  fullPath = lib.custom.relativeToRoot path;
                in
                lib.optional (lib.pathExists fullPath) fullPath;
            in
            {
              "${user}".imports = lib.flatten [
                (map fullPathIfExists [
                  "home/${user}/${hostSpec.hostName}.nix"
                  "home/${user}/common"
                  "home/${user}/common/nixos.nix"
                ])
                (
                  { ... }:
                  {
                    home = {
                      stateVersion = "25.11";
                      homeDirectory = "/home/${user}";
                      username = user;
                    };
                  }
                )
              ];
            })
          hostSpec.users
      ))
      // {
        root = {
          home.stateVersion = "25.11";
          programs.zsh.enable = true;
        };
      };
  };
}

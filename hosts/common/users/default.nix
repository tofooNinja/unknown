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

  # Generate host-scoped list of public key contents for a user.
  # All hosts get the shared fallback key; Pi hosts additionally trust
  # service-specific keys used during key migration/rotation.
  genPubKeyList =
    user:
    let
      keyPath = lib.custom.relativeToRoot "hosts/common/users/${user}/keys";
      allHostKeys = [
        "tofoo_all_no_pw.pub"
      ];
      piOnlyKeys = [
        "id_ed25519_github.pub"
        "id_ed25519_sk_github.pub"
        "id_ed25519_pis.pub"
        "id_ed25519_sk_pis.pub"
        "id_ed25519_gitlab.pub"
        "id_ed25519_sk_gitlab.pub"
        "id_ed25519_home_server.pub"
        "id_ed25519_sk_home_server.pub"
      ];
      selectedKeyFiles = allHostKeys ++ lib.optionals hostSpec.isPi piOnlyKeys;

      readKeyFile =
        fileName:
        let
          fullPath = "${keyPath}/${fileName}";
        in
        lib.optional (lib.pathExists fullPath) (lib.readFile fullPath);
    in
    if (lib.pathExists keyPath) then
      lib.flatten (map readKeyFile selectedKeyFiles)
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
              extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "dialout" ];
              openssh.authorizedKeys.keys = genPubKeyList user;
              home = "/home/${user}";
            }
            // (
              if hostSpec.enableSops then
                { hashedPasswordFile = config.sops.secrets."passwords/${user}".path; }
              else
                { hashedPassword = "$6$NEZC6bEazrGNF22H$9zytJUR5ucZBDu0wPpJHP9bAyxee7q26YTRxrrsNrqRBoodoh8LA5yz6sKvvsA2oQfn6Wdc7d41/rN8Gq8/Zm0"; } #nix
            );
          })
          hostSpec.users
      ))
      // {
        root =
          {
            shell = pkgs.zsh;
            openssh.authorizedKeys.keys =
              config.users.users.${hostSpec.primaryUsername}.openssh.authorizedKeys.keys;
          }
          // (
            if hostSpec.enableSops then
              { hashedPasswordFile = config.users.users.${hostSpec.primaryUsername}.hashedPasswordFile; }
            else
              { hashedPassword = "$6$NEZC6bEazrGNF22H$9zytJUR5ucZBDu0wPpJHP9bAyxee7q26YTRxrrsNrqRBoodoh8LA5yz6sKvvsA2oQfn6Wdc7d41/rN8Gq8/Zm0"; }
          );
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

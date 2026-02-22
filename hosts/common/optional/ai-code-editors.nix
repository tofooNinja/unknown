# AI code editors - Cursor, Claude Code, Gemini CLI, Qwen Code
{ config, lib, pkgs, ... }:
lib.mkIf (config.hostSpec.aiCodeEditorsEnable or false) {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "cursor" "claude" "gemini-cli" "qwen-code" ];

  environment.systemPackages = with pkgs; [
    code-cursor
    claude-code
    opencode
  ] ++ lib.optionals (pkgs ? gemini-cli) [ gemini-cli ]
  ++ lib.optionals (pkgs ? qwen-code) [ qwen-code ];
}

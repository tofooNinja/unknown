# Find Home Manager backup conflicts from journal and optionally remove
{ pkgs, ... }:
pkgs.writeShellScriptBin "hm-find" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  echo "==============================================="
  echo "            ⚠️ WARNING ⚠️            "
  echo "==============================================="
  echo "*** This script is experimental! ***"
  echo "It will attempt to find old backup files that are preventing Home Manager from rebuilding."
  echo "If conflicting files are found, you will be prompted to remove them."
  echo "A log of any deletions will be stored in \$HOME/hm-logs."
  echo "==============================================="

  TIME_RANGE="30m"
  LOG_DIR="$HOME/hm-logs"
  LOG_FILE="$LOG_DIR/hm-cleanup-$(date +'%Y-%m-%d_%H-%M-%S').log"

  [ -d "$LOG_DIR" ] || { echo "Creating log directory: $LOG_DIR"; mkdir -p "$LOG_DIR"; }

  FILES=$(journalctl --user --since "-$TIME_RANGE" -xe 2>/dev/null | grep hm-activate | awk -F "'|'" '/would be clobbered by backing up/ {print $2}' || true)
  [ -n "$FILES" ] || { echo "No conflicting backup files found in the last $TIME_RANGE."; exit 0; }

  echo "🚨 The following backup files are preventing Home Manager from rebuilding:"
  echo "$FILES" | tr ' ' '\n'
  read -p "❓ Do you want to remove these files? (y/N): " confirm

  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    echo "🗑️ Deleting files..." | tee -a "$LOG_FILE"
    echo "$FILES" | xargs rm -v | tee -a "$LOG_FILE"
    echo "✅ Cleanup completed at $(date)" | tee -a "$LOG_FILE"
  else
    echo "⛔ No files were removed." | tee -a "$LOG_FILE"
  fi
''

#!/usr/bin/env bash
# Update Raspberry Pi OS (Raspbian / Raspberry Pi OS) safely and non-interactively
set -euo pipefail

PROG_NAME="$(basename "$0")"
LOG_FILE="/var/log/update-raspios.log"

print_help() {
  cat <<EOF
Usage: $PROG_NAME [options]

Options:
  -y    Auto-yes to prompts (run non-interactively)
  -n    Dry-run (print what would be done)
  -r    Reboot after successful upgrade
  -h    Show this help

This script updates the package lists, upgrades installed packages,
performs autoremove/autoclean, and optionally reboots the Pi.
It is safe to run multiple times.
EOF
}

DRY_RUN=0
AUTO_YES=0
REBOOT_AFTER=0

while getopts ":ynrh" opt; do
  case "$opt" in
    y) AUTO_YES=1 ;;
    n) DRY_RUN=1 ;;
    r) REBOOT_AFTER=1 ;;
    h) print_help; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument."; exit 2 ;;
    *) print_help; exit 2 ;;
  esac
done

log() {
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "[$ts] $*" | tee -a "$LOG_FILE"
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY: $*"
  else
    log "$*"
    # shellcheck disable=SC2086
    $*
  fi
}

require_root_or_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY: would re-run under sudo"
    else
      echo "Re-running script under sudo..."
      exec sudo bash "$0" "$@"
    fi
  fi
}

check_network() {
  # quick network check
  if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

waiting_for_apt() {
  # wait for dpkg/apt locks to clear for up to 60s
  local tries=0
  local max=30
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    if [ "$tries" -ge "$max" ]; then
      return 1
    fi
    sleep 2
    tries=$((tries + 1))
  done
  return 0
}

main() {
  require_root_or_sudo "$@"

  mkdir -p "$(dirname "$LOG_FILE")" || true

  log "Starting Raspberry Pi OS update"

  if ! check_network; then
    log "Network unreachable. Aborting."
    echo "Network unreachable. Check your connection and try again." >&2
    exit 3
  fi

  if ! waiting_for_apt; then
    log "apt/dpkg lock held for too long. Aborting."
    echo "Package system appears busy (dpkg/apt lock). Try again later." >&2
    exit 4
  fi

  # Update package lists
  if [ "$AUTO_YES" -eq 1 ]; then
    run apt-get update
  else
    run apt-get update
  fi

  # Upgrade packages (full-upgrade to handle kernel/module changes)
  if [ "$AUTO_YES" -eq 1 ]; then
    run apt-get -y full-upgrade
  else
    run apt-get full-upgrade
  fi

  # Remove no-longer-needed packages and clean cache
  if [ "$AUTO_YES" -eq 1 ]; then
    run apt-get -y autoremove
    run apt-get -y autoclean
  else
    run apt-get autoremove
    run apt-get autoclean
  fi

  # Optional: user can choose to run rpi-update manually if they want bleeding-edge firmware.
  log "Update complete"

  if [ "$REBOOT_AFTER" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY: would reboot now"
    else
      log "Rebooting system as requested"
      sync
      reboot
    fi
  fi

  log "Done"
}

main "$@"

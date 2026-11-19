#!/usr/bin/env bash
# Ubuntu/Debian package helper (uses nala when available, falls back to apt).
#
#   ./packages.sh [install]   install nala (if possible) and everything in packages-apt.txt
#   ./packages.sh export      list the packages you installed by hand (needs nala)
#
# Set DRY_RUN=1 to print the commands instead of running them.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="${DOTFILES}/packages-apt.txt"

run() {
  if [ "${DRY_RUN:-0}" = "1" ]; then echo "[dry-run] $*"; else "$@"; fi
}

export_packages() {
  # Packages manually installed through nala
  nala list -i -N | grep -P '^[^├└]' | awk '{print $1}'
}

install_packages() {
  command -v apt-get >/dev/null 2>&1 || { echo "apt-get not found: this script is for Ubuntu/Debian." >&2; exit 1; }

  run sudo apt-get update

  pm=(apt-get)
  if ! command -v nala >/dev/null 2>&1; then
    echo "Installing nala..."
    if run sudo apt-get install -y nala; then
      pm=(nala)
    else
      echo "nala is not available in this release's repositories, continuing with apt-get."
    fi
  else
    pm=(nala)
  fi
  [ "${DRY_RUN:-0}" = "1" ] && pm=(nala)

  wanted=()
  skipped=()
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if [ "${DRY_RUN:-0}" = "1" ] || apt-cache show "$pkg" >/dev/null 2>&1; then
      wanted+=("$pkg")
    else
      skipped+=("$pkg")
    fi
  done < <(grep -vE '^\s*(#|$)' "$LIST")

  if [ ${#wanted[@]} -gt 0 ]; then
    run sudo "${pm[@]}" install -y "${wanted[@]}"
  fi
  [ ${#skipped[@]} -gt 0 ] && echo "Skipped (not in this release's repos): ${skipped[*]}"

  # Debian/Ubuntu rename these binaries; add the usual names under ~/.local/bin
  run mkdir -p "$HOME/.local/bin"
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    run ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    run ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
  return 0
}

case "${1:-install}" in
  install) install_packages ;;
  export) export_packages ;;
  -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" ;;
  *) echo "Usage: $0 [install|export]" >&2; exit 2 ;;
esac

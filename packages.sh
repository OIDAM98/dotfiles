#!/usr/bin/env bash
# Ubuntu/Debian system packages: Homebrew's prerequisites and zsh, via nala when available.
# Everything else is installed from the Brewfile with Homebrew (install.sh does both).
#
#   ./packages.sh [install]   install nala (if possible) and the packages in packages-apt.txt
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
  if command -v nala >/dev/null 2>&1; then
    pm=(nala)
  else
    echo "Installing nala..."
    if run sudo apt-get install -y nala; then
      pm=(nala)
    else
      echo "nala is not available in this release's repositories, continuing with apt-get."
    fi
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
  if [ ${#skipped[@]} -gt 0 ]; then
    echo "Skipped (not in this release's repos): ${skipped[*]}"
  fi
  return 0
}

case "${1:-install}" in
  install) install_packages ;;
  export) export_packages ;;
  -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" ;;
  *) echo "Usage: $0 [install|export]" >&2; exit 2 ;;
esac

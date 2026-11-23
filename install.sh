#!/usr/bin/env bash
# Bootstrap a machine from this repo: packages, antidote, then symlinks via stow.
#
#   ./install.sh [-n|--dry-run] [--no-packages] [--no-stow]
#
# Ubuntu/Debian:  apt/nala only for Homebrew's prerequisites and zsh (./packages.sh)
# macOS + Linux:  Homebrew (installed if missing), then `brew bundle` from the Brewfile
# Both:           antidote -> ~/.antidote, yazi plugins (if yazi is installed), ./stowall
#
# Machine-local files (work identities, corporate certs) are NOT created here; copy the
# templates from examples/ afterwards (see examples/README.md).

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dry_run=0
do_packages=1
do_stow=1

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=1 ;;
    --no-packages) do_packages=0 ;;
    --no-stow) do_stow=0 ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if [ "$dry_run" -eq 1 ]; then echo "[dry-run] $*"; else "$@"; fi
}

os="$(uname -s)"
distro=""
if [ "$os" = "Linux" ] && [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  distro="$(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}")"
fi

echo "== Detected: ${os} ${distro}"

find_brew() {
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    [ -x "$b" ] && { echo "$b"; return 0; }
  done
  command -v brew
}

if [ "$do_packages" -eq 1 ]; then
  case "$os" in
    Darwin) ;;
    Linux)
      if [[ "$distro" == *ubuntu* || "$distro" == *debian* ]]; then
        echo "== System packages (apt/nala): Homebrew prerequisites and zsh"
        DRY_RUN="$dry_run" "${DOTFILES}/packages.sh" install
      else
        echo "Unsupported Linux distro (${distro}): install Homebrew's prerequisites manually."
      fi
      ;;
    *) echo "Unsupported OS: ${os}; skipping packages."; do_packages=0 ;;
  esac
fi

if [ "$do_packages" -eq 1 ]; then
  brew_bin="$(find_brew || true)"
  if [ -z "$brew_bin" ]; then
    echo "== Installing Homebrew"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew_bin="$(find_brew || true)"
  fi
  if [ -n "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
  fi
  echo "== brew bundle"
  run brew bundle --file="${DOTFILES}/Brewfile"
fi

echo "== antidote"
if [ -d "$HOME/.antidote" ]; then
  echo "already installed"
else
  run git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
fi

if [ "$do_stow" -eq 1 ]; then
  echo "== stow"
  if [ "$dry_run" -eq 1 ]; then
    "${DOTFILES}/stowall" --dry-run || true
  else
    "${DOTFILES}/stowall"
  fi
fi

if command -v ya >/dev/null 2>&1 && [ "$dry_run" -eq 0 ]; then
  echo "== yazi plugins"
  ya pkg install || echo "ya pkg install failed (run it manually later)"
fi

echo "---"
echo "Next steps:"
echo "  - Copy and edit the templates in examples/ for machine-local settings."
case "${SHELL:-}" in
  *zsh) ;;
  *) echo "  - Make zsh your login shell: chsh -s \"\$(command -v zsh)\"" ;;
esac
echo "  - Open a new terminal."

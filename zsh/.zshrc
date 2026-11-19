### ENV ###
export EDITOR="hx"
export SUDO_EDITOR="$(command -v hx)"
export ZELLIJ_AUTO_ATTACH=true
export LC_ALL="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"
export TERM="xterm-256color"
export NVM_DIR="$HOME/.nvm"
export GOPATH="$HOME/go"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export BR_INSTALL="no"
export FZF_ALT_C_COMMAND=""
export SSL_CERT_FILE=/etc/ssl/cert.pem
export REQUESTS_CA_BUNDLE=/etc/ssl/cert.pem
export PYENV_ROOT="$HOME/.pyenv"

### PATH (deduplicated; first entry wins) ###
typeset -U path PATH fpath
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  [[ -x $_brew ]] && { eval "$("$_brew" shellenv)"; break; }
done
unset _brew
path=(
  $HOME/bin
  $HOME/.local/bin
  $HOME/.cargo/bin
  $HOME/go/bin
  $HOME/.lmstudio/bin
  $HOME/.emacs.d/bin
  $HOME/.codeium/windsurf/bin
  $PYENV_ROOT/bin
  $PYENV_ROOT/shims
  /usr/local/bin
  $path
)
path=(${^path}(N-/))   # drop entries that don't exist
[[ -n $HOMEBREW_PREFIX && -d $HOMEBREW_PREFIX/share/zsh/site-functions ]] && fpath+=($HOMEBREW_PREFIX/share/zsh/site-functions)
fpath=(~/.zsh/completions $fpath)

### ZELLIJ auto-start ###
# Runs first so the outer shell does no extra work; the shell inside zellij loads everything below.
if [[ -o interactive ]] && command -v zellij >/dev/null; then
  eval "$(zellij setup --generate-auto-start zsh)"
fi

### ANTIDOTE ###
# `antidote load` regenerates ~/.zsh_plugins.zsh when ~/.zsh_plugins.txt changes, then sources it.
source ~/.antidote/antidote.zsh
antidote load

### ALIASES ###
alias zshreload="source ~/.zshrc"
alias ls="eza -l --color=always --group-directories-first"
alias l="eza -l --color=always --group-directories-first"
alias la="eza -alh --color=always --group-directories-first"
alias ll='eza -l --color=always --group-directories-first'
alias tree='eza -aT --color=always --group-directories-first'
alias df="df -h"
alias free="free -h"
alias docker-status='docker ps -a --format "table{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.RunningFor}}\t{{.State}}"'
alias lg="lazygit"
alias ..="cd .."

### FUNCTIONS ###
# yazi: cd to the directory yazi exits in
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# broot: run the command broot produces (needed for cd)
function br {
    local cmd cmd_file code
    cmd_file=$(mktemp)
    if broot --outcmd "$cmd_file" "$@"; then
        cmd=$(<"$cmd_file")
        command rm -f "$cmd_file"
        eval "$cmd"
    else
        code=$?
        command rm -f "$cmd_file"
        return "$code"
    fi
}

### KITTY ###
if [ -n "$KITTY_WINDOW_ID" ]; then
  export TERM="xterm-kitty"
  ssh() {
    if command -v kitty >/dev/null 2>&1; then
      command kitty +kitten ssh "$@"
    else
      command ssh "$@"
    fi
  }
fi

### PROMPT ###
eval "$(starship init zsh)"

### DEFERRED (run after the first prompt is drawn) ###
# zoxide replaces cd with a smart cd (cdi = interactive)
zsh-defer -c 'eval "$(zoxide init zsh --cmd cd)"'
zsh-defer -c 'eval "$(direnv hook zsh)"'
zsh-defer -c 'eval "$(pyenv init - zsh)"; eval "$(pyenv virtualenv-init - zsh)"'
# nvm: prefer the Homebrew install, fall back to ~/.nvm
zsh-defer -c 'if [ -n "$HOMEBREW_PREFIX" ] && [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]; then . "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"; elif [ -s "$NVM_DIR/nvm.sh" ]; then . "$NVM_DIR/nvm.sh"; fi'
zsh-defer -c '[[ -s ~/.zsh/completions/cortex.zsh ]] && source ~/.zsh/completions/cortex.zsh'

### MACHINE-LOCAL ###
# Work-specific and installer-managed lines (Claude, nc-os, etc.) live in ~/.zshrc.local, not versioned.
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

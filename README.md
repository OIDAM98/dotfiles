# Dotfiles

My configuration for macOS and Ubuntu/Debian. Each top-level folder is a [GNU Stow](https://www.gnu.org/software/stow/) package that mirrors the home directory (for example `helix/.config/helix/config.toml` is linked to `~/.config/helix/config.toml`).

- **Shell:** zsh with [antidote](https://github.com/mattmc3/antidote) (plugins in `zsh/.zsh_plugins.txt`), starship, zoxide, zellij auto-start
- **Editor and tools:** helix (with sqruff for SQL and yaml-language-server), yazi, lazygit, kitty and others
- **Packages:** one `Brewfile` for Homebrew on macOS and Linux; `packages-apt.txt` only has the Ubuntu/Debian prerequisites

## New machine

```sh
git clone git@github.com:OIDAM98/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # preview
./install.sh
```

`install.sh` detects the OS and then:

- **Ubuntu/Debian:** installs `nala` and the few system packages in `packages-apt.txt` (Homebrew prerequisites and zsh) through `./packages.sh`
- **macOS and Linux:** installs Homebrew if missing (Linuxbrew on Linux), then runs `brew bundle` on the shared `Brewfile`
- **Both:** clones antidote to `~/.antidote`, runs `./stowall`, and installs yazi plugins if yazi is present

Options: `--no-packages`, `--no-stow`, `-n/--dry-run`.

## Symlinks

```sh
./stowall -n            # dry run: show what would be linked
./stowall               # link every package
./stowall helix zsh     # only some packages
./stowall --adopt       # pull real files that are in the way INTO the repo (overwrites repo copies; review git diff)
```

Without `--adopt`, an existing real file is reported as a conflict and left alone. `adopt_new.sh` moves new, unmanaged `~/.config` folders into new packages.

## Machine-local files (not in the repo)

Work identities, corporate certificates and installer-added shell lines are kept out of this public repo. Templates are in [`examples/`](examples/README.md):

- `~/.gitconfig-local`: included from `git/.gitconfig`, holds per-directory identities and the corporate CA
- `~/.zshrc.local`: sourced at the end of `.zshrc`
- `~/.config/snow-run/env`: optional settings for the Helix Snowflake runner

## Notes

- Yazi plugins and flavors are installed from `package.toml` with `ya pkg install`; they are not versioned.
- Fonts are Homebrew casks on macOS only; on Linux put them in `~/.local/share/fonts`.
- `./packages.sh export` lists the packages you installed by hand with nala (Ubuntu).

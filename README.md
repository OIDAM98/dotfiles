# Dotfiles

Current version of my dotfiles.

Right now it uses 
- `GNU Stow` as a dependency and symlink manager.
- `Antidote` as ZSH plugin manager

And it only works with **Ubuntu**

## Before running

```sh
# Installing GNU Stow to manage symlinks
sudo apt install stow -y

# Installing ZSH Plugin Manager Antidote
git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote
```

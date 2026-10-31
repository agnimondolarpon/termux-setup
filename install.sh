#!/usr/bin/env bash
# Termux setup installer: packages, zsh plugins, dotfiles.
# Usage: bash install.sh [--link] [--no-pkg] [--no-plugins] [--no-chsh] [-h]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$HOME/.zsh/plugins"
STAMP="$(date +%Y%m%d-%H%M%S)"

PKGS=(zsh git clang neovim nano)

MODE=copy
DO_PKG=1
DO_PLUGINS=1
DO_CHSH=1

usage() {
  cat <<'USAGE'
Usage: bash install.sh [options]

  --link         symlink dotfiles into $HOME instead of copying them
  --no-pkg       skip 'pkg install'
  --no-plugins   skip cloning zsh plugins
  --no-chsh      do not change the default shell to zsh
  -h, --help     show this help
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --link)       MODE=link ;;
    --no-pkg)     DO_PKG=0 ;;
    --no-plugins) DO_PLUGINS=0 ;;
    --no-chsh)    DO_CHSH=0 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 1 ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }

# Copy or link SRC to DEST. An existing different file is backed up first.
install_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"

  if [[ "$MODE" == link ]]; then
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      log "ok (already linked): $dest"; return
    fi
  elif [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
    log "ok (unchanged): $dest"; return
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    mv -- "$dest" "$dest.bak.$STAMP"
    warn "backed up old file -> $dest.bak.$STAMP"
  fi

  if [[ "$MODE" == link ]]; then
    ln -s -- "$src" "$dest"
    log "linked: $dest -> $src"
  else
    cp -- "$src" "$dest"
    log "copied: $dest"
  fi
}

clone_plugin() {
  local name="$1" url="$2" dir="$PLUGIN_DIR/$1"
  if [[ -d "$dir/.git" ]]; then
    log "updating plugin: $name"
    git -C "$dir" pull --ff-only || warn "could not update $name (offline?)"
  else
    log "cloning plugin: $name"
    mkdir -p "$PLUGIN_DIR"
    git clone --depth 1 "$url" "$dir"
  fi
}

# ---- 1. packages -----------------------------------------------------------
if (( DO_PKG )); then
  if command -v pkg >/dev/null 2>&1; then
    log "installing packages: ${PKGS[*]}"
    pkg update -y
    pkg install -y "${PKGS[@]}"
  else
    warn "'pkg' not found (not running in Termux?). Skipping packages."
  fi
fi

# ---- 2. zsh plugins --------------------------------------------------------
if (( DO_PLUGINS )); then
  if command -v git >/dev/null 2>&1; then
    clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
    clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
  else
    warn "git not found. Skipping plugins."
  fi
fi

# ---- 3. dotfiles -----------------------------------------------------------
install_file "$REPO_DIR/zsh/zshrc"                  "$HOME/.zshrc"
install_file "$REPO_DIR/termux/termux.properties"   "$HOME/.termux/termux.properties"
install_file "$REPO_DIR/termux/colors.properties"   "$HOME/.termux/colors.properties"

# ---- 4. default shell ------------------------------------------------------
if (( DO_CHSH )) && command -v chsh >/dev/null 2>&1 && command -v zsh >/dev/null 2>&1; then
  if [[ "$(basename "${SHELL:-}")" != zsh ]]; then
    log "setting default shell to zsh"
    chsh -s zsh || warn "chsh failed; run 'chsh -s zsh' manually"
  fi
fi

# ---- 5. apply Termux settings ---------------------------------------------
if command -v termux-reload-settings >/dev/null 2>&1; then
  termux-reload-settings
fi

log "done. Close and reopen Termux (or run: exec zsh)."

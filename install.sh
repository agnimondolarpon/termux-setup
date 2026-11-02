#!/usr/bin/env bash
# install.sh - set up zsh and the Termux dotfiles in this repository.
#
# Works when started from bash (the Termux default): zsh and git are installed
# (or upgraded) first, then the plugins and dotfiles are set up, and finally
# zsh becomes the default shell. Safe to run again.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

PLUGIN_DIR="$HOME/.zsh/plugins"
STAMP="$(date +%Y%m%d-%H%M%S)"

# Minimum needed to bring zsh up; everything else lives in install-pkg.sh.
BOOTSTRAP_PKGS=(zsh git)

MODE=copy
DO_PKG=1
DO_PLUGINS=1
DO_CHSH=1
DO_PACKAGES=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

  --link         symlink dotfiles into $HOME instead of copying them
  --packages     afterwards run install-pkg.sh (base + dev + security)
  --no-pkg       skip installing zsh/git (assume they are already there)
  --no-plugins   skip cloning the zsh plugins
  --no-chsh      do not change the default shell to zsh
  -h, --help     show this help
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --link)       MODE=link ;;
    --packages)   DO_PACKAGES=1 ;;
    --no-pkg)     DO_PKG=0 ;;
    --no-plugins) DO_PLUGINS=0 ;;
    --no-chsh)    DO_CHSH=0 ;;
    -h|--help)    usage; exit 0 ;;
    *) warn "unknown option: $arg"; usage >&2; exit 1 ;;
  esac
done

# Copy or link SRC to DEST. A differing existing file is backed up first.
install_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"

  if [[ "$MODE" == link ]]; then
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      ok "already linked: $dest"; return 0
    fi
  elif [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
    ok "unchanged: $dest"; return 0
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

# ---- 1. zsh + git ----------------------------------------------------------
UPDATED_INDEX=0
if (( DO_PKG )); then
  if have_pkg_manager; then
    refresh_index
    UPDATED_INDEX=1
    load_upgradable
    ensure_pkgs "${BOOTSTRAP_PKGS[@]}"
    report_problems
  else
    warn "'pkg' not found (not running in Termux?) - skipping package installation"
  fi
fi

# ---- 2. zsh plugins --------------------------------------------------------
if (( DO_PLUGINS )); then
  if command -v git >/dev/null 2>&1; then
    clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
    clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
  else
    warn "git not found - skipping plugins"
  fi
fi

# ---- 3. dotfiles -----------------------------------------------------------
install_file "$REPO_DIR/zsh/zshrc"                 "$HOME/.zshrc"
install_file "$REPO_DIR/termux/termux.properties"  "$HOME/.termux/termux.properties"
install_file "$REPO_DIR/termux/colors.properties"  "$HOME/.termux/colors.properties"

# ---- 4. default shell ------------------------------------------------------
if (( DO_CHSH )) && command -v chsh >/dev/null 2>&1 && command -v zsh >/dev/null 2>&1; then
  if [[ "$(basename "${SHELL:-}")" != zsh ]]; then
    log "setting default shell to zsh"
    chsh -s zsh || warn "chsh failed - run 'chsh -s zsh' manually"
  fi
fi

# ---- 5. apply Termux settings ----------------------------------------------
if command -v termux-reload-settings >/dev/null 2>&1; then
  termux-reload-settings
fi

# ---- 6. optional: everything else ------------------------------------------
if (( DO_PACKAGES )); then
  log "running install-pkg.sh"
  if (( UPDATED_INDEX )); then
    bash "$REPO_DIR/install-pkg.sh" --no-update
  else
    bash "$REPO_DIR/install-pkg.sh"
  fi
else
  printf '\nTip: run ./install-pkg.sh to install the dev and security tools.\n'
fi

log "done. Close and reopen Termux (or run: exec zsh)."

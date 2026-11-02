#!/usr/bin/env bash
# backup.sh - copy the live config from $HOME back into this repository,
# then show what changed. Review with `git diff` before committing.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pull_file() {
  local src="$1" dest="$2"
  if [[ "$src" -ef "$dest" ]]; then
    echo "skip (linked to repo): $src"
  elif [[ -f "$src" ]]; then
    cp -L -- "$src" "$dest"
    echo "saved: $src -> ${dest#"$REPO_DIR"/}"
  else
    echo "skip (missing): $src" >&2
  fi
}

pull_file "$HOME/.zshrc"                     "$REPO_DIR/zsh/zshrc"
pull_file "$HOME/.termux/termux.properties"  "$REPO_DIR/termux/termux.properties"
pull_file "$HOME/.termux/colors.properties"  "$REPO_DIR/termux/colors.properties"

echo
git -C "$REPO_DIR" status --short

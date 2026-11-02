#!/usr/bin/env bash
# install-pkg.sh - install the Termux packages listed in packages/*.txt.
#
# For every package:
#   not installed        -> installed
#   installed, outdated  -> upgraded to the latest version
#   installed, current   -> skipped
#   not in the repos     -> reported and skipped
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$REPO_DIR/packages"
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

DEFAULT_GROUPS=(base dev security)
GROUPS_SELECTED=()
DO_ALL=0
DO_LIST=0
DO_UPDATE=1
DO_FULL_UPGRADE=0
DO_REPOS=0

usage() {
  cat <<'USAGE'
Usage: ./install-pkg.sh [options]

Installs or upgrades the packages in packages/<group>.txt.
Default groups: base, dev, security.

  -g, --group LIST    comma-separated groups to use (e.g. base,dev)
  -a, --all           use every group, including 'extra'
  -l, --list          show groups and their packages, then exit
  -n, --dry-run       show what would change without changing anything
      --no-update     do not refresh the package index first
      --full-upgrade  also upgrade every other installed package first
      --with-repos    enable unstable-repo (extra security tools, e.g. metasploit)
  -h, --help          show this help

Examples:
  ./install-pkg.sh                    # base + dev + security
  ./install-pkg.sh -g dev             # only the dev toolchain
  ./install-pkg.sh --all --dry-run    # preview everything
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    -g|--group)
      [[ $# -ge 2 ]] || die "$1 needs a value"
      IFS=',' read -r -a _g <<< "$2"
      GROUPS_SELECTED+=("${_g[@]}")
      shift ;;
    --group=*)
      IFS=',' read -r -a _g <<< "${1#--group=}"
      GROUPS_SELECTED+=("${_g[@]}") ;;
    -a|--all)       DO_ALL=1 ;;
    -l|--list)      DO_LIST=1 ;;
    -n|--dry-run)   DRY_RUN=1 ;;
    --no-update)    DO_UPDATE=0 ;;
    --full-upgrade) DO_FULL_UPGRADE=1 ;;
    --with-repos)   DO_REPOS=1 ;;
    -h|--help)      usage; exit 0 ;;
    *) warn "unknown option: $1"; usage >&2; exit 1 ;;
  esac
  shift
done

# Print the package names of one group file (comments and blanks removed).
read_group() {
  sed 's/#.*//' "$PKG_DIR/$1.txt" | awk 'NF { print $1 }'
}

all_groups() {
  local f
  for f in "$PKG_DIR"/*.txt; do
    basename "$f" .txt
  done
}

if (( DO_LIST )); then
  for g in $(all_groups); do
    printf '%s%s%s\n' "$TS_BOLD" "$g" "$TS_RESET"
    read_group "$g" | sed 's/^/  /'
  done
  exit 0
fi

if (( DO_ALL )); then
  mapfile -t GROUPS_SELECTED < <(all_groups)
elif (( ${#GROUPS_SELECTED[@]} == 0 )); then
  GROUPS_SELECTED=("${DEFAULT_GROUPS[@]}")
fi

for g in "${GROUPS_SELECTED[@]}"; do
  [[ -f "$PKG_DIR/$g.txt" ]] || die "unknown group '$g' (available: $(all_groups | tr '\n' ' '))"
done

have_pkg_manager || die "pkg/apt not found - this script must run inside Termux"

# ---- repositories ----------------------------------------------------------
if (( DO_REPOS )); then
  if pkg_installed unstable-repo; then
    ok "unstable-repo already enabled"
  elif [[ "$DRY_RUN" == 1 ]]; then
    log "would enable unstable-repo"
  else
    log "enabling unstable-repo"
    pkg install -y unstable-repo
  fi
fi

# ---- index / optional full upgrade ----------------------------------------
if (( DO_UPDATE )); then
  refresh_index
fi
if (( DO_FULL_UPGRADE )); then
  if [[ "$DRY_RUN" == 1 ]]; then
    log "would upgrade all installed packages"
  else
    log "upgrading all installed packages"
    pkg upgrade -y
  fi
fi
load_upgradable

# ---- packages --------------------------------------------------------------
declare -A seen=()
for g in "${GROUPS_SELECTED[@]}"; do
  log "group: $g"
  pkgs=()
  while IFS= read -r name; do
    if [[ -z "${seen[$name]:-}" ]]; then
      seen["$name"]=1
      pkgs+=("$name")
    fi
  done < <(read_group "$g")
  if (( ${#pkgs[@]} > 0 )); then
    ensure_pkgs "${pkgs[@]}"
  fi
done

print_summary

if (( ${#UNAVAILABLE[@]} > 0 && DO_REPOS == 0 )); then
  printf '\nTip: some tools live in extra repositories - try: ./install-pkg.sh --with-repos\n'
fi

if (( ${#FAILED[@]} > 0 )); then
  exit 1
fi

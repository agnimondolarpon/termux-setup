#!/usr/bin/env bash
# Shared helpers for the termux-setup scripts.
# This file is meant to be sourced, not executed.
# shellcheck shell=bash

# ---- output ----------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  TS_RESET=$'\033[0m'; TS_BOLD=$'\033[1m'
  TS_RED=$'\033[31m'; TS_GREEN=$'\033[32m'; TS_YELLOW=$'\033[33m'; TS_BLUE=$'\033[34m'
else
  TS_RESET=''; TS_BOLD=''; TS_RED=''; TS_GREEN=''; TS_YELLOW=''; TS_BLUE=''
fi

log()  { printf '%s==>%s %s\n' "${TS_BOLD}${TS_BLUE}" "$TS_RESET" "$*"; }
ok()   { printf '%s ok%s  %s\n' "${TS_BOLD}${TS_GREEN}" "$TS_RESET" "$*"; }
warn() { printf '%s !!%s  %s\n' "${TS_BOLD}${TS_YELLOW}" "$TS_RESET" "$*" >&2; }
die()  { printf '%sERR%s  %s\n' "${TS_BOLD}${TS_RED}" "$TS_RESET" "$*" >&2; exit 1; }

# ---- package state ---------------------------------------------------------
DRY_RUN="${DRY_RUN:-0}"

declare -A UPGRADABLE=()   # name -> 1 for every installed package with a newer candidate
declare -A CANDIDATE=()    # name -> candidate version (filled by ensure_pkgs)

N_INSTALLED=0
N_UPGRADED=0
N_CURRENT=0
UNAVAILABLE=()
FAILED=()

have_pkg_manager() {
  command -v pkg >/dev/null 2>&1 && command -v apt-cache >/dev/null 2>&1 \
    && command -v dpkg-query >/dev/null 2>&1
}

# Refresh the package index only. (`pkg update` is a full upgrade in Termux.)
refresh_index() {
  log "refreshing package index"
  apt-get update || warn "could not refresh the package index (offline?) - using the cached one"
}

# Fill UPGRADABLE from `apt list --upgradable`.
load_upgradable() {
  UPGRADABLE=()
  local line name
  while IFS= read -r line; do
    name="${line%%/*}"
    if [[ -n "$name" ]]; then
      UPGRADABLE["$name"]=1
    fi
  done < <(apt list --upgradable 2>/dev/null | awk 'NR > 1')
}

pkg_installed() {
  [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" == installed ]]
}

pkg_version() {
  dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true
}

# Print the repository candidate version, or nothing if the package is unknown.
pkg_candidate() {
  local cand
  cand="$(apt-cache policy "$1" 2>/dev/null | awk '/^ *Candidate:/ { print $2; exit }')" || true
  if [[ "$cand" == "(none)" ]]; then
    cand=''
  fi
  printf '%s' "$cand"
}

# Install the packages in "$@"; fall back to one-by-one if the batch fails so a
# single bad package cannot block the rest.
_pkg_run() {
  if pkg install -y "$@"; then
    return 0
  fi
  warn "batch install failed - retrying one package at a time"
  local p
  for p in "$@"; do
    pkg install -y "$p" || true
  done
}

# ensure_pkgs NAME...
#   not installed            -> install
#   installed, outdated      -> upgrade to the latest version
#   installed, up to date    -> skip
#   not in any repository    -> recorded in UNAVAILABLE
ensure_pkgs() {
  local name cand
  local -a missing=() outdated=()

  for name in "$@"; do
    cand="$(pkg_candidate "$name")"
    if [[ -z "$cand" ]]; then
      UNAVAILABLE+=("$name")
      continue
    fi
    CANDIDATE["$name"]="$cand"
    if pkg_installed "$name"; then
      if [[ -n "${UPGRADABLE[$name]:-}" ]]; then
        outdated+=("$name")
      else
        N_CURRENT=$((N_CURRENT + 1))
      fi
    else
      missing+=("$name")
    fi
  done

  if (( ${#missing[@]} + ${#outdated[@]} == 0 )); then
    return 0
  fi

  if (( ${#missing[@]} > 0 )); then
    log "install: ${missing[*]}"
  fi
  if (( ${#outdated[@]} > 0 )); then
    log "upgrade: ${outdated[*]}"
  fi

  if [[ "$DRY_RUN" == 1 ]]; then
    N_INSTALLED=$((N_INSTALLED + ${#missing[@]}))
    N_UPGRADED=$((N_UPGRADED + ${#outdated[@]}))
    return 0
  fi

  _pkg_run "${missing[@]}" "${outdated[@]}"

  for name in "${missing[@]}"; do
    if pkg_installed "$name"; then
      N_INSTALLED=$((N_INSTALLED + 1))
    else
      FAILED+=("$name")
    fi
  done
  for name in "${outdated[@]}"; do
    if [[ "$(pkg_version "$name")" == "${CANDIDATE[$name]}" ]]; then
      N_UPGRADED=$((N_UPGRADED + 1))
    else
      FAILED+=("$name")
    fi
  done
}

report_problems() {
  if (( ${#UNAVAILABLE[@]} > 0 )); then
    warn "not available in the enabled repositories (skipped): ${UNAVAILABLE[*]}"
  fi
  if (( ${#FAILED[@]} > 0 )); then
    warn "failed: ${FAILED[*]}"
  fi
}

print_summary() {
  local suffix=''
  if [[ "$DRY_RUN" == 1 ]]; then
    suffix=' (dry run - nothing was changed)'
  fi
  printf '\n%sSummary%s%s\n' "$TS_BOLD" "$TS_RESET" "$suffix"
  printf '  installed   : %d\n' "$N_INSTALLED"
  printf '  upgraded    : %d\n' "$N_UPGRADED"
  printf '  up to date  : %d\n' "$N_CURRENT"
  printf '  unavailable : %d\n' "${#UNAVAILABLE[@]}"
  printf '  failed      : %d\n' "${#FAILED[@]}"
  report_problems
}

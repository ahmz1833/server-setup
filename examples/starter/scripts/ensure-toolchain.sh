#!/usr/bin/env bash
# ensure-toolchain.sh — make an IaC project runnable on this machine.
#
# Source of truth: ahmz1833/server-setup scripts/ensure-toolchain.sh
# (copied into examples/*/scripts/ and the infra skills; do not edit the copies).
#
# What it does (idempotent, safe to run every time):
#   1. Finds a WORKING ansible (project .venv first, then system). If none works
#      creates ./.venv (uv if available, else python3 -m venv) from requirements.txt.
#   2. Installs/upgrades collections from requirements.yml into ./collections —
#      i.e. the LATEST ahmz1833.server_setup unless pinned.
#   3. Optionally links a local collection checkout for co-development.
#   4. Installs the AI agent skills (infra-iac, infra-bootstrap, server-setup-dev) user-wide
#      with `npx skills` if no agent has them yet (best-effort; needs node/npx).
#
# Usage:  scripts/ensure-toolchain.sh [PROJECT_DIR]
# Env:
#   SERVER_SETUP_VERSION=1.5.0    pin the collection instead of installing latest
#   COLLECTION_SRC=../server-setup use a local checkout of the collection (symlink)
#   NO_UPGRADE=1                  do not upgrade already-installed collections
#   PYTHON=python3.12             interpreter for the venv
#   SKIP_SKILLS=1                 don't install the agent skills
#   USE_VENV=1                    ignore a system ansible, always use ./.venv
#
# Exit codes: 0 ok, 2 no usable python (use the Docker runner: make docker-shell)

set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

log() { printf '\033[1;34m[toolchain]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[toolchain]\033[0m %s\n' "$*" >&2; }

GIT_URL="https://github.com/ahmz1833/server-setup.git"
COLL_DIR="./collections"

# --- 1. ansible ---------------------------------------------------------------
works() { "$1" --version >/dev/null 2>&1; }

ANSIBLE_BIN_DIR=""
if [ -x .venv/bin/ansible-playbook ] && works .venv/bin/ansible-playbook; then
  ANSIBLE_BIN_DIR=".venv/bin"
elif [ "${USE_VENV:-0}" != "1" ] && command -v ansible-playbook >/dev/null 2>&1 \
     && works ansible-playbook; then
  ANSIBLE_BIN_DIR="$(dirname "$(command -v ansible-playbook)")"
fi

if [ -z "$ANSIBLE_BIN_DIR" ]; then
  # ansible-core supports a window of Python versions; pick one that really runs
  # (pyenv shims may exist on PATH without working).
  PY="${PYTHON:-}"
  if [ -z "$PY" ]; then
    for c in python3.13 python3.12 python3.11 python3; do
      if "$c" -c 'import sys; sys.exit(not ((3,11) <= sys.version_info[:2] <= (3,13)))' \
           >/dev/null 2>&1; then PY="$c"; break; fi
    done
  fi
  if command -v uv >/dev/null 2>&1; then
    log "creating .venv with uv"
    # without a usable local python, uv fetches a managed 3.12
    uv venv -q -p "${PY:-3.12}" .venv
    VIRTUAL_ENV="$PWD/.venv" uv pip install -q -r requirements.txt
  elif [ -n "$PY" ]; then
    log "creating .venv with $PY"
    "$PY" -m venv .venv
    .venv/bin/pip install -q --upgrade pip
    .venv/bin/pip install -q -r requirements.txt
  else
    warn "no python found. Use the Docker runner instead: make docker-shell"
    exit 2
  fi
  ANSIBLE_BIN_DIR=".venv/bin"
fi
GALAXY="$ANSIBLE_BIN_DIR/ansible-galaxy"
# resolve/install against ./collections only, so a user-wide copy never masks the latest
export ANSIBLE_COLLECTIONS_PATH="$PWD/collections"
log "ansible: $("$ANSIBLE_BIN_DIR/ansible-playbook" --version | head -1)"

# --- 2. collections -------------------------------------------------------------
mkdir -p "$COLL_DIR"
UPGRADE_FLAG="--upgrade"
if [ "${NO_UPGRADE:-0}" = "1" ]; then UPGRADE_FLAG=""; fi

if [ -f requirements.yml ]; then
  log "installing collections from requirements.yml (${UPGRADE_FLAG:-no upgrade})"
  if ! "$GALAXY" collection install -r requirements.yml -p "$COLL_DIR" $UPGRADE_FLAG; then
    warn "galaxy install failed (network/galaxy blocked?) — falling back to git for server_setup"
    "$GALAXY" collection install "git+$GIT_URL" -p "$COLL_DIR" --force
  fi
fi

if [ -n "${SERVER_SETUP_VERSION:-}" ]; then
  log "pinning ahmz1833.server_setup==$SERVER_SETUP_VERSION"
  "$GALAXY" collection install "ahmz1833.server_setup:==${SERVER_SETUP_VERSION}" \
    -p "$COLL_DIR" --force \
  || "$GALAXY" collection install "git+$GIT_URL,v${SERVER_SETUP_VERSION}" -p "$COLL_DIR" --force
fi

# --- 3. local checkout (co-development) ----------------------------------------
if [ -n "${COLLECTION_SRC:-}" ]; then
  SRC="$(cd "$COLLECTION_SRC" && pwd)"
  DEST="$COLL_DIR/ansible_collections/ahmz1833/server_setup"
  mkdir -p "$(dirname "$DEST")"
  rm -rf "$DEST"
  ln -s "$SRC" "$DEST"
  log "linked local collection checkout: $SRC"
fi

CDIR="$COLL_DIR/ansible_collections/ahmz1833/server_setup"
VER="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$CDIR/MANIFEST.json" 2>/dev/null | head -1 || true)"
if [ -z "$VER" ]; then
  VER="$(sed -n 's/^version: *//p' "$CDIR/galaxy.yml" 2>/dev/null | head -1 || true)"
fi
log "ahmz1833.server_setup: ${VER:-unknown} (in $COLL_DIR)"

# --- 4. agent skills --------------------------------------------------------------
skills_present() {
  local d
  for d in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.codex/skills" \
           "$HOME/.cursor/skills" ./.claude/skills ./.agents/skills; do
    [ -f "$d/infra-iac/SKILL.md" ] && return 0
  done
  # Claude Code plugin installs
  [ -d "$HOME/.claude/plugins" ] && \
    find "$HOME/.claude/plugins" -maxdepth 6 -path '*infra-iac/SKILL.md' -print -quit 2>/dev/null | grep -q .
}
if [ "${SKIP_SKILLS:-0}" != "1" ] && ! skills_present; then
  if command -v npx >/dev/null 2>&1; then
    log "installing agent skills (user-wide): npx skills add ahmz1833/server-setup"
    npx -y skills add ahmz1833/server-setup -g -y --skill '*' >/dev/null 2>&1 \
      && log "agent skills installed" \
      || warn "skills install failed — run: make skills (bundled copy: $COLL_DIR/ansible_collections/ahmz1833/server_setup/skills/)"
  else
    warn "no npx: agent skills not installed. Agents can read the bundled copy in $COLL_DIR/ansible_collections/ahmz1833/server_setup/skills/"
  fi
fi
log "ready. Try: make help"

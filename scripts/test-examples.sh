#!/usr/bin/env bash
# test-examples.sh — prove every example project works against THIS checkout.
#
# For each examples/<name>: copy to a temp dir, install the collection built from this
# repo (+ deps) into its ./collections, create throw-away vaults from *.example, then:
#   vault-check · syntax-check every playbook · make validate (argument specs) · ansible-lint
# No server is contacted. Requires ansible-core, ansible-lint, make, openssl on PATH.
#
# Usage: scripts/test-examples.sh [example ...]     (default: all)
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT

log() { printf '\033[1;34m[test]\033[0m %s\n' "$*"; }

log "building collection"
ansible-galaxy collection build --force --output-path "$WORK/dist" >/dev/null
TARBALL="$(ls "$WORK"/dist/*.tar.gz)"
ansible-galaxy collection install "$TARBALL" -p "$WORK/collections" >/dev/null

examples=("$@")
[ ${#examples[@]} -eq 0 ] && examples=($(cd examples && ls -d */ | tr -d /))

fail=0
for ex in "${examples[@]}"; do
  d="$WORK/$ex"
  cp -r "examples/$ex" "$d"
  cp -r "$WORK/collections" "$d/collections"
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyForCIOnly0000000000000000000000 ci" \
    > "$d/files/ssh_keys/admin.pub"
  for env in $(ls "$d/inventories"); do
    tag="$ex/$env"
    ( cd "$d"
      make -s vault-init ENV="$env" VAULT_PER_ENV=1 >/dev/null
      make -s vault-check >/dev/null
      for p in $(find playbooks -name '*.yml' | sort); do
        pb="${p#playbooks/}"; pb="${pb%.yml}"
        make -s check PLAY="$pb" ENV="$env" EXTRA=--syntax-check >/dev/null
      done
      make -s validate ENV="$env" > "$WORK/$ex-$env.log" 2>&1 \
        || { cat "$WORK/$ex-$env.log"; exit 1; }
    ) && log "OK   $tag (vault, syntax, validate)" || { log "FAIL $tag"; fail=1; }
  done
  ( cd "$d" && ANSIBLE_COLLECTIONS_PATH="$d/collections" ansible-lint --offline -q playbooks $( [ -d roles ] && echo roles ) ) \
    && log "OK   $ex (ansible-lint)" || { log "FAIL $ex (ansible-lint)"; fail=1; }
done
exit $fail

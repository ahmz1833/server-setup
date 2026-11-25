#!/usr/bin/env bash
# sync.sh — propagate single-source files into their copies.
#
#   docs/*.md                          -> skills/infra-iac/references/
#   docs/debugging.md                  -> skills/server-diagnostics/references/
#   scripts/ensure-toolchain.sh        -> examples/*/scripts/, skills/infra-iac/scripts/
#   examples/starter/<shared files>    -> examples/<other>/   (Makefile, configs, ops playbooks)
#   examples/starter/                  -> skills/infra-bootstrap/assets/starter/
#   docs/roles-index.md                (regenerated from argument specs)
#
# Usage: scripts/sync.sh [--check]   (--check: fail if anything is out of date; for CI)
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1
STAGE="$(mktemp -d)"
trap 'rm -rf -- "$STAGE"' EXIT

PY="${PYTHON:-python3}"

# Copy src -> dst (file or directory) inside a staging tree mirroring the repo.
put() {
  local src="$1" dst="$2"
  mkdir -p "$STAGE/$(dirname "$dst")"
  if [ -d "$src" ]; then
    mkdir -p "$STAGE/$dst"
    (cd "$src" && tar --exclude='./.venv' --exclude='./collections' --exclude='.vault_pass*' \
      --exclude='vault.yml' -cf - .) | (cd "$STAGE/$dst" && tar -xf -)
  else
    cp "$src" "$STAGE/$dst"
  fi
}

SHARED=(Makefile ansible.cfg requirements.txt .gitignore .yamllint .ansible-lint
        files/ssh_keys/README.md playbooks/ops/restart.yml playbooks/ops/reboot.yml
        playbooks/ops/upgrade.yml)

# 1. roles index
if [ "$CHECK" = 1 ]; then
  "$PY" scripts/gen-roles-index.py --check
else
  "$PY" scripts/gen-roles-index.py
fi

# 2. docs -> infra-iac references
for f in docs/*.md; do put "$f" "skills/infra-iac/references/$(basename "$f")"; done
put docs/debugging.md skills/server-diagnostics/references/debugging.md
put scripts/ensure-toolchain.sh skills/infra-iac/scripts/ensure-toolchain.sh

# 3. starter shared files -> other examples
for ex in examples/*/; do
  ex="${ex%/}"
  put scripts/ensure-toolchain.sh "$ex/scripts/ensure-toolchain.sh"
  [ "$ex" = examples/starter ] && continue
  for f in "${SHARED[@]}"; do put "examples/starter/$f" "$ex/$f"; done
done

# 4. starter -> bootstrap skill asset (after step 3 so it carries the fresh script)
put examples/starter skills/infra-bootstrap/assets/starter
put scripts/ensure-toolchain.sh skills/infra-bootstrap/assets/starter/scripts/ensure-toolchain.sh

# Compare / apply
drift=0
while IFS= read -r -d '' f; do
  rel="${f#"$STAGE"/}"
  if [ "$CHECK" = 1 ]; then
    if ! cmp -s "$f" "$rel"; then echo "out of date: $rel"; drift=1; fi
  else
    mkdir -p "$(dirname "$rel")"
    cmp -s "$f" "$rel" || { cp "$f" "$rel"; echo "synced: $rel"; }
  fi
done < <(find "$STAGE" -type f -print0)

# Files in the bootstrap asset that no longer exist in the starter
while IFS= read -r -d '' f; do
  rel="${f#skills/infra-bootstrap/assets/starter/}"
  if [ ! -e "examples/starter/$rel" ] && [ "$rel" != "scripts/ensure-toolchain.sh" ]; then
    if [ "$CHECK" = 1 ]; then echo "stale: $f"; drift=1; else echo "stale (remove by hand): $f"; fi
  fi
done < <(find skills/infra-bootstrap/assets/starter -type f -print0 2>/dev/null)

chmod +x examples/*/scripts/ensure-toolchain.sh skills/*/scripts/*.sh \
  skills/infra-bootstrap/assets/starter/scripts/ensure-toolchain.sh 2>/dev/null || true

if [ "$CHECK" = 1 ] && [ "$drift" = 1 ]; then
  echo "run scripts/sync.sh and commit the result" >&2
  exit 1
fi
[ "$CHECK" = 1 ] && echo "sync: up to date"
exit 0

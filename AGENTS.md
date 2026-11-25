# Agent Guidelines & Release Workflow

All agents and contributors working on **this collection repository** must follow these
rules. (Operating *infrastructure* with the collection is covered by the `infra-iac` skill
and `docs/`; developing the collection by the `server-setup-dev` skill in `skills/`.)

---

## 0. What lives here

| Path | Source of truth? |
|---|---|
| `roles/<role>/` (defaults, tasks, templates, README, `meta/argument_specs.yml`) | yes |
| `docs/*.md` | yes (except `docs/roles-index.md`, generated) |
| `examples/starter/` | yes — shared files are copied from here into the other examples |
| `examples/{multi-env-cluster,fleet}/` | yes, except the files `scripts/sync.sh` copies in |
| `scripts/ensure-toolchain.sh` | yes — copied into examples and skills |
| `skills/*/SKILL.md` | yes |
| `skills/infra-iac/references/`, `skills/*/scripts/`, `skills/infra-bootstrap/assets/starter/` | **generated copies** — never edit; run `scripts/sync.sh` |

---

## 1. Documentation & Metadata Consistency (Mandatory)

Keep metadata and documentation strictly synchronized with code changes:
- **Role variables**: whenever a variable or feature is added, changed or deprecated, update
  the role's `defaults/main.yml`, `meta/argument_specs.yml`, `README.md` and templates in
  the same change.
- **Argument specs**: every user-settable variable is declared; types permissive (`raw` for
  templated/polymorphic values; `required` only when the role cannot work without it);
  **no `{{`, `{%` or `{#` anywhere in a spec file** (Ansible templates the spec at runtime).
- **Generated/copied files**: run `scripts/sync.sh` after touching argument specs, `docs/`,
  `examples/starter/` or `scripts/ensure-toolchain.sh`. CI fails on drift.
- **Root docs & examples**: keep root `README.md`, `docs/` and `examples/` aligned with real
  parameters and defaults. Examples and docs use `example.com` and RFC 5737/3849 addresses —
  never real domains, IPs, usernames or secrets (the repo is public).

### Doc-impact checklist (every change to a role — mandatory, same PR/commit series)

A role change is not done until every place that describes it is true again. Go through
this list and touch whatever applies; say in the PR which items you updated or why none
applied.

1. **Search first**: `grep -rn '<var_or_feature>' roles docs examples skills README.md`
   for every variable, tag, file path, default or behaviour you added, renamed, removed or
   changed. Every hit is a candidate to update.
2. `roles/<role>/defaults/main.yml` — variable with its default and a comment.
3. `roles/<role>/meta/argument_specs.yml` — option, type, default, description (and the
   role's `Tags:` line if tags changed); also any other entry point (`tasks_from`).
4. `roles/<role>/README.md` — variables tables, task order, tags, requirements, examples,
   limitations.
5. `roles/<role>/examples/*.yml` and other roles that include or depend on it
   (`include_role`, `tasks_from`, shared variables such as `core_firewall_rules`).
6. Root `README.md` — roles overview, quick examples, cross-role variables.
7. `docs/*.md` — any guidance that names the variable/behaviour (security defaults,
   debugging tips, operations) — and `examples/*` projects that configure it.
8. `skills/*/SKILL.md` — if the workflow or a rule changes.
9. `scripts/sync.sh` → regenerated `docs/roles-index.md` and skill copies.
10. `CHANGELOG.md` entry (+ version bump at release).

`scripts/check-consistency.py` (CI) mechanically verifies defaults ⇄ argument specs
(every default declared, literal defaults equal, no Jinja in specs); `scripts/sync.sh
--check` verifies generated copies; `scripts/test-examples.sh` validates the examples
against the role specs. Prose accuracy (READMEs, docs) is on you and the reviewer.

---

## 2. Commit, Versioning & Release Workflow

### A. Incremental & Conventional Commits
- Atomic commits scoped by domain (`fix(k3s): ...`, `feat(node): ...`, `docs: ...`,
  `feat(skills): ...`). Don't mix unrelated multi-role changes in one commit.

### B. Version Bumping & Changelog Updates
- **`galaxy.yml`**: bump the semantic version (patch: fixes; minor: features/new
  variables/docs/skills; major: breaking). Keep `.claude-plugin/*.json` `version` equal.
- **`CHANGELOG.md`**: every release has `## [X.Y.Z] - YYYY-MM-DD` with `### Added`,
  `### Changed`, `### Fixed`. Never bump or merge without it.

### C. Git Tagging
- Tag every release commit: `git tag v<major>.<minor>.<patch>`. The tag triggers Galaxy
  publish and the `ghcr.io/ahmz1833/server-setup:<version>` image.

---

## 3. Verification & Cleanliness
- `ansible-lint roles`, `scripts/check-consistency.py`, `scripts/sync.sh --check`,
  `scripts/test-examples.sh`.
- `ansible-galaxy collection build` and `ansible-doc -t role ahmz1833.server_setup.<role>`.
- For variable/spec changes: `make validate` in the examples (with
  `COLLECTION_SRC=<this repo> make setup`).
- Working tree clean; no scratch artifacts, no decrypted vaults, no `.vault_pass*`.

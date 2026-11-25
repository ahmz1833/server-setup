---
name: server-setup-dev
description: Develop, fix or extend the ahmz1833.server_setup Ansible collection itself (its roles core, node, nginx, acme, apps, sandbox, k3s, mail, asset; argument specs; docs; examples; skills) - or upstream a generic local role into it. Use when working inside the server-setup repository, when a project needs a feature the collection lacks, or when a collection bug is found while operating infrastructure. Covers both maintainers (write access, release workflow) and non-owners (local workaround + issue/PR).
---

# Working on the server_setup collection

Repository: https://github.com/ahmz1833/server-setup (namespace `ahmz1833`, collection
`server_setup`). The repo's own `AGENTS.md` is authoritative for contributor rules; this
skill summarizes and adds the workflow around it.

## 1. Who are you in this repo?

Check: is the current directory a clone with push access (`git remote -v`,
`gh repo view --json viewerPermission` if `gh` is available), or are you in a consumer
project?

| Situation | Path |
|---|---|
| Maintainer (write access) | §2 release workflow |
| Not an owner, have a fork / can open PRs | §2 on a fork, open a PR, no tag/publish |
| Consumer project, no time for upstream | §3 local workaround now + issue |

## 2. Change workflow (maintainer or PR author)

1. Branch from `master`: `feat/<role>-<topic>` or `fix/<role>-<topic>`.
2. Make the change **in the role** (defaults, tasks, templates, handlers). Keep roles
   generic: no project names, real domains, IPs or secrets — examples use `example.com`
   and RFC 5737 addresses.
3. Keep code and docs consistent — part of the change, never a follow-up. Run the
   repo's **doc-impact checklist** (`AGENTS.md` §1): start by grepping
   `roles docs examples skills README.md` for every variable/tag/behaviour you touched and
   update every hit. In short:
   - `roles/<role>/defaults/main.yml` (new var with a commented default)
   - `roles/<role>/meta/argument_specs.yml` — every user-settable var; permissive types
     (`raw` for templated/polymorphic, no `required` unless the role cannot work without
     it); **never `{{`, `{%` or `{#` anywhere in the spec** (Ansible templates the spec
     and the role breaks at runtime).
   - `roles/<role>/README.md`, root `README.md` if user-facing.
   - role `examples/`, roles that include this one, root `README.md` (overview, quick
     examples, cross-role variables), `docs/` guidance and `examples/` projects that use it,
     `skills/*/SKILL.md` if a workflow/rule changes, `CHANGELOG.md`.
   - Run `scripts/sync.sh` → regenerates `docs/roles-index.md` and copies docs, starter and
     shared files into `skills/` and other examples. Never edit the copies directly.
4. Verify:
   - `ansible-lint roles`, `scripts/check-consistency.py` (defaults ⇄ argument specs),
     `scripts/test-examples.sh` (examples vs specs, lint)
   - `ansible-galaxy collection build` + install to a temp path;
     `ansible-doc -t role ahmz1833.server_setup.<role>` renders.
   - Argument specs vs real vars without servers: in an example (or consumer project with
     `COLLECTION_SRC=<this repo> make setup`), run `make validate`.
   - Behaviour: a disposable VM/container if available (`make check` then `apply`).
     Never test on production hosts without the owner's explicit OK.
   - `scripts/sync.sh --check` clean.
   - Reread the role README and the docs hits from the grep: do they describe the new
     behaviour exactly? Report in the summary which docs you updated.
5. Release (maintainers): conventional, atomic commits (`feat(nginx): …`,
   `fix(core): …`, `docs: …`); bump `galaxy.yml` version (semver: patch = fix,
   minor = feature/new var, major = breaking); add `CHANGELOG.md` entry
   `## [X.Y.Z] - YYYY-MM-DD` with Added/Changed/Fixed; tag `vX.Y.Z`. Pushing the tag
   publishes to Galaxy and builds `ghcr.io/ahmz1833/server-setup:X.Y.Z` (CI).
   Commit, push and tag only when the user asks.

Breaking changes (renamed/removed variables, changed defaults that alter running
systems): avoid; if needed, keep the old name working with a deprecation note for one
minor release and call it out in CHANGELOG.

## 3. Consumer project needs something the collection lacks

1. Implement it in the project as a small local role (`roles/<name>/`), idempotent,
   variables prefixed with the role name, marked at the top of `tasks/main.yml`:
   `# UPSTREAM-CANDIDATE: <what and why it's generic>`.
2. Collection bug? Work around it in the project with a comment linking the issue; do not
   patch files under `collections/` (they are overwritten by `make setup`).
3. Draft an issue (or PR) for the collection: problem, proposed variables/behaviour,
   example config. Use `gh issue create -R ahmz1833/server-setup` only if the user asks —
   and strip any project-specific names, IPs and domains first (public repo).
4. Co-developing: `COLLECTION_SRC=../server-setup make setup` symlinks a local checkout
   into the project so you can test a collection change against real inventory
   (`make validate`, `make check`).

## 4. Design principles for collection code

- Declarative variables over task-level switches; sensible secure defaults (deny by
  default, loopback binds, keys-only SSH).
- Idempotent tasks; `changed_when`/`creates` on commands; `no_log` for secrets.
- Feature toggles follow the existing `<role>_<feature>_install` / `_enabled` /
  `<role>_manage_<area>` patterns; tags `<role>` and `<role>-<area>`.
- Shared download/install logic goes through the `asset` role.
- Work on Debian/Ubuntu first; guard family-specific tasks.

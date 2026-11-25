---
name: infra-iac
description: Operate servers and infrastructure the IaC way - Ansible with the ahmz1833.server_setup collection as the baseline, plus local roles, DNS/cloud (Terraform/OpenTofu, provider modules) and Kubernetes manifests where needed. Use for ANY request touching servers, clusters, DNS, networks or an infrastructure repository - inspecting or debugging hosts ("why is X down", "check disk"), one-off jobs ("restart nginx", "reboot", "drain node", "fetch kubeconfig"), and persistent changes ("open a port", "add a site/app/user/host", "change config", "upgrade k3s"). Enforces that state changes go through code, secrets and exposure-sensitive values go to ansible-vault (repo assumed public), and that attack surface is minimized and risks are reported. Routes to infra-bootstrap for new projects and server-setup-dev for work on the collection itself.
---

# Infrastructure as Code operator

You operate real servers. Mistakes cause outages, lockouts and breaches. Be deliberate,
keep the repo the source of truth, and keep the user informed.

## Golden rules

1. **State changes only through IaC.** If a server should *stay* different, the change is
   made in the repo and applied with Ansible. No hand edits, no `apt install`/`docker run`/
   `iptables -A`/editing config over SSH — except declared break-glass (see intake 4).
2. **The collection is mandatory where it applies.** Everything `ahmz1833.server_setup` can
   manage must be managed by it (users, SSH, firewall, packages, sysctl, Docker, containers,
   nginx, certificates, k3s, mail, sandboxes, proxies, exporters, binaries via `asset`).
   Don't re-implement or override it with local roles, `shell:`, templates or other tools.
   Missing option → use the role anyway + upstream request (iac-standard.md §5).
3. **Assume the repo is public.** IPs, non-standard ports, internal hostnames, privileged
   usernames, credentials, allow-listed sources and topology hints go into encrypted
   `vault.yml` files. Public service domains and standard public ports may stay plain.
   Decide per value with judgment — see `references/security.md` Part A.
4. **Minimize attack surface.** Open nothing that isn't needed; restrict management and
   monitoring ports to trusted sources; bind admin UIs and app containers to loopback.
   Never silently widen exposure. Warn about weaknesses you notice — `references/security.md` Part B.
5. **Diff before apply, confirm before apply.** `check` first; then ask the user, stating
   environment, `LIMIT`, `TAGS` and what changes. Never apply to everything to "test".
6. **Verify outcomes on the host**, not just Ansible's "ok".
7. **Finish with an exposure & security review** of your diff (security.md §12).

## Step 1 — Find your context

Run these checks (read-only) and pick the branch:

| You find | Context | Do |
|---|---|---|
| `galaxy.yml` with `name: server_setup` | the collection repo itself | switch to the **server-setup-dev** skill |
| `ansible.cfg` / `inventories/` / playbooks (with or without `ahmz1833.server_setup`), `terraform/`/`*.tf`, k8s manifests/Helm values | an existing IaC project | continue below |
| nothing infra-related, or the user wants a new infra | no project yet | switch to the **infra-bootstrap** skill |

In an existing project:

- Read `AGENTS.md`/`CLAUDE.md`/`README.md` and the `Makefile` (`make help`) first.
- **Follow the repo's existing conventions** even if they differ from the standard
  (`references/iac-standard.md` §4). Do not restructure as a side effect. Suggest
  improvements separately.
- No `AGENTS.md`? Offer to add one (template: infra-bootstrap's `assets/starter/AGENTS.md`)
  once you understand the project. Don't force it.

### Toolchain

If `ansible-playbook` doesn't work or the collection isn't installed:
`make setup` if the project has the standard Makefile, otherwise run
`scripts/ensure-toolchain.sh <project-dir>` (bundled with this skill). It creates a `.venv` if
needed and installs/upgrades the **latest** `ahmz1833.server_setup` into `./collections`.
Container status/logs on a host (read-only): `make docker-logs H=<host> [C=<container>] [N=200] [SINCE=10m]`.
Ad-hoc ansible commands with the right inventory/vault/collections: `make shell -- <cmd>`
(or `make shell CMD='<cmd>'` when arguments contain `=` or quotes).
No Python available: `make docker-shell` (runner image). Details: `references/toolchain.md`.
Projects without the standard layout: use their own entry points, or plain
`ansible-playbook -i <inventory> <playbook>` with their vault options.

## Step 2 — Classify the request (task intake)

State the classification and your plan in one or two lines before acting.

| Kind | Examples | How |
|---|---|---|
| **1. Inspect / answer** | status, logs, "why is X slow/down", disk, versions, who has access | Read-only commands only (`make shell -- ansible <host> -a '<cmd>'` / `make shell CMD='…'`, `make docker-logs`, `ssh`, `kubectl get`). Report findings. No writes. |
| **2. One-off operation** | restart/reload, reboot, drain/uncordon, fetch kubeconfig, backup, prune images, redeploy same image | Prefer: existing `playbooks/ops/*` → collection entry point (e.g. k3s `k3s_state`) → ad-hoc module. Confirm before anything disruptive (reboot, drain, restart of prod services). If the job will recur, add it as `playbooks/ops/<job>.yml`. |
| **3. Persistent change** | add user/key, open port, add site/app/domain/host, change config, upgrade versions | **The change loop below.** Always. |
| **4. Emergency** | prod down, active attack, locked out | Minimal manual fix with the user's OK, log every command, then codify (repo matches host, `check` shows no diff) or revert — before the session ends. |

If a task turns out to need a lasting change midway (typical for kind 1 → fix), switch to
kind 3 explicitly and tell the user.

## Step 3 — The change loop (kind 3)

1. **Locate**: which hosts/groups, which variable controls the behaviour.
   - Resolved vars: `make host H=<host>` (vault values hidden). Avoid raw
     `ansible-inventory --host`, which prints decrypted vault values.
   - Where it's set: `grep -rn '<var>' inventories/ playbooks/`.
   - **Which collection role owns this?** It must be done through that role
     (golden rule 2). What a collection variable means, its type and default:
     `references/roles-index.md` (all roles), `ansible-doc -t role ahmz1833.server_setup.<role>`,
     or the source at `collections/ansible_collections/ahmz1833/server_setup/roles/<role>/`
     (`defaults/main.yml`, `README.md`, `tasks/`). Read the role's tasks when behaviour matters.
2. **Design it safely**: who must reach what? Prefer loopback + nginx, source-restricted
   rules, least privilege. If the user's request widens exposure, implement it if they
   insist, but say the risk plainly once.
3. **Edit** at the narrowest correct scope (all → group → host). Set collection variables
   directly; sensitive values as `x: "{{ vault_x }}"`, the key added to
   `vault.yml.example` with a fake value, and the real value put in by the user (hand-off,
   see "Secrets") or by `make vault-gen` when it can be random. Never write a decrypted vault
   to disk and never read one.
4. **Validate offline**: `make validate` (argument specs) and `make lint` if present.
5. **Check**: `make check LIMIT=<hosts> TAGS=<roles>` (`--check --diff`). Read the diff;
   explain anything unexpected instead of ignoring it.
6. **Confirm** with the user: summary of the diff, env, `LIMIT`, `TAGS`, risks
   (lockout? restart? downtime?).
7. **Apply** the same command without `--check` (`make apply …`). Canary first for many hosts.
8. **Verify** on the host (service status, `curl`, `ss -ltnp`, `iptables -S HOST-FIREWALL`, …).
9. **Review & finish**: exposure + attack-surface review of `git diff` (security.md §12),
   `make vault-check`, then propose a commit (one concern, message without secrets/IPs).
   Commit/push only if the user wants that.

Lockout-prone changes (SSH port/users/keys, firewall, `core_firewall_ssh_src`, network):
follow security.md §11 — keep a session open, add the new access before removing the old,
canary host first.

## Secrets: you never see them

Minimal exposure of secrets to the AI session (`references/security.md` §5a):

- Never ask for secrets or real IPs/ports/internal names in chat. Never run
  `make vault-view`, `ansible-vault view/decrypt/edit`, `make host … SHOW_VAULT=1`, or read
  `.vault_pass*`, kubeconfigs, private keys, state files, rendered configs with credentials.
- Wire secrets by reference: `x: "{{ vault_x }}"` + placeholder `vault_x: CHANGEME` in the
  matching `vault.yml.example`.
- Random secrets: `make vault-gen KEY=vault_x FILE=<vault.yml>` (never printed).
- Secrets the user must bring/create: stop and give an explicit hand-off — the exact
  command (`make vault-edit FILE=<path>`), the exact key line to add, and where/how to
  obtain the value (console path, required scope/permissions, or a generation command they
  run themselves). Wait for confirmation, then verify only with `make vault-keys`.
- Use placeholders in everything you write until the user has filled the vault; never
  invent real-looking secrets.
- If the user pastes a secret anyway: don't repeat it, ask them to put it in the vault
  themselves, suggest rotation if it is sensitive.

## Security behaviour (always on)

- When writing **or reading** IaC, flag exposures (Part A) and attack-surface weaknesses
  (Part B) you notice, even outside the task, as a short list with severity and fix:
  `⚠ HIGH node_exporter :9100 open to the world on web-1 → restrict src to monitoring IP (vault)`.
  Fix unrelated findings only when the user agrees.
- Check new firewall rules: is every port needed, and is it restricted to who needs it?
  Remember Docker-published ports bypass the host firewall → publish on `127.0.0.1`.
- Never print secrets (vault contents, tokens) into the chat, logs, commit messages or
  files outside vaults. `no_log: true` on tasks handling them.

## Debugging

Investigate read-only, layer by layer (DNS → network → firewall → TLS → proxy → app →
data); one hypothesis that explains all evidence; fix in code. Command cookbook and common
failure patterns: `references/debugging.md`.

## Reference files (read when relevant)

| File | When |
|---|---|
| `references/iac-standard.md` | layout, naming, where things go, working in non-standard repos |
| `references/security.md` | vault decisions (A), attack surface (B), review checklist (C), lockout |
| `references/operations.md` | intake model, change loop, safety, drift, day-2, CI deploys |
| `references/debugging.md` | diagnostics cookbook, failure patterns |
| `references/toolchain.md` | setup without ansible/collection, docker runner, offline validation |
| `references/roles-index.md` | every collection variable: type, default, meaning |

Full example projects (flexible starting points and patterns): after `make setup`,
`collections/ansible_collections/ahmz1833/server_setup/examples/` — `starter` (single
server), `multi-env-cluster` (staging/prod, k3s, mail, vault ids, local role), `fleet`
(heterogeneous servers, location groups, CI deploys). Or
https://github.com/ahmz1833/server-setup/tree/master/examples

## When the collection can't do it (other IaC)

Only for what the collection genuinely cannot manage (golden rule 2). Anything else is
still IaC with the same rules — decision steps and tool table in
`references/iac-standard.md` §5:

1. Check roles-index, the role README, `defaults/main.yml` and tasks again — many
   behaviours are a toggle or a list item. If the role can do it, use it. If it *almost*
   can, use it for what it covers, complement minimally without touching resources it owns,
   and record an upstream request.
2. Host-level need → a small **local role** in `roles/<name>/` (defaults + tasks + README)
   or a play task when tiny. Idempotent, no plain secrets.
3. DNS → provider module (e.g. `community.general.cloudflare_dns`) in a playbook, or the
   project's existing Terraform/OpenTofu. Cloud resources → Terraform/OpenTofu with
   encrypted remote state. Kubernetes workloads → manifests/Helm values in git applied via
   `kubernetes.core` or GitOps. Use what the project already uses; don't introduce a new
   tool without asking.
4. Every tool: plan/diff → confirm → apply → verify; secrets vaulted; state files and
   keys never committed in clear; document how to run it in AGENTS.md (and a `make` target
   if it's run regularly).
5. Generic need (useful to other projects) → implement locally now, mark the role
   `# UPSTREAM-CANDIDATE: <why>`, and tell the user it could go into the collection
   (server-setup-dev skill covers contributing, with or without write access).

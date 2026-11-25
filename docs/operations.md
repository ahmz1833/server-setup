# Operating infrastructure with IaC

How to handle any request against servers — "change something", "do something", "find
something out" — while keeping the repo the source of truth. Written for humans; the
`infra-iac` agent skill follows exactly the same model.

> Related: [iac-standard.md](iac-standard.md) · [security.md](security.md) ·
> [debugging.md](debugging.md)

---

## 1. Task intake: classify before acting

Every request falls into one of four kinds. Decide which **before** touching anything,
and say it out loud (in the PR, the ticket, or the chat with the agent).

| Kind | Examples | How | Repo changes? |
|---|---|---|---|
| **1. Inspect / answer** | "is X up?", "why is the site slow?", "disk usage?", "which k3s version?", "who can sudo?" | read-only commands (`make shell -- ansible …`, `make docker-logs`, ssh, `kubectl get`) | no |
| **2. One-off operation** | restart/reload a service, reboot, drain/uncordon a node, fetch kubeconfig, run a backup, prune images, re-pull & redeploy same image, renew a cert now | an existing ops playbook / role entry point, or an ad-hoc module call | no — unless the job will recur → add `playbooks/ops/<job>.yml` |
| **3. Persistent change** | add a user/key, open a port, add a site/app/domain, change any config, add/remove a host, upgrade a version | **IaC only**: edit repo → check → confirm → apply → verify | yes, always |
| **4. Emergency** | prod is down, active attack, locked out | break-glass fix by hand, then codify or revert in the same session | yes, right after |

Rules of thumb:

- If after the task the server should **stay** different from what the repo describes, it
  is kind 3. "Just quickly `apt install` / edit nginx.conf / `docker run`" is kind 3.
- A restart is kind 2. Changing what is restarted, or how, is kind 3.
- A task can change kind mid-way: investigating (1) often ends in a fix (3). Switch
  explicitly.

## 2. The change loop (kind 3)

1. **Locate** where the setting lives: `make host H=<host>` shows the resolved vars;
   `grep -rn <var> inventories/` finds the file; [roles-index.md](roles-index.md) shows
   which collection variable controls the behaviour and its default.
2. **Edit** the narrowest correct scope (all → group → host). Sensitive literals go to the
   vault ([security.md](security.md)).
3. **Check**: `make check LIMIT=<host> TAGS=<role>` — read the diff. Check mode is not
   perfect (tasks depending on earlier changes may report errors/skips); understand any
   difference rather than ignoring it.
4. **Confirm** with whoever owns the system (for agents: always ask before apply, show the
   diff summary, the limit and the tags).
5. **Apply** with the same `LIMIT`/`TAGS`. Canary first when touching many hosts.
6. **Verify** the outcome on the host (service status, curl the endpoint, `ss -ltnp`, …).
   "Ansible said ok" is not verification.
7. **Exposure review** of the diff, `make vault-check`, then commit — one concern per
   commit, message says what and why (no secrets/IPs in the message).

## 3. One-off operations (kind 2)

Prefer, in this order:

1. An ops playbook already in the repo: `make run PLAY=ops/restart EXTRA="-e service=nginx" LIMIT=web-1`.
2. A collection role entry point that does it (e.g. k3s `k3s_state: drain|uncordon|fetch-kubeconfig`).
3. An ad-hoc module call:
   `make shell CMD='ansible web-1 -b -m ansible.builtin.systemd_service -a "name=nginx state=restarted"'`.
4. A raw shell command — only when nothing above fits; keep it read-only or explicitly
   ephemeral.

If you notice you are running the same ad-hoc job a second time, turn it into
`playbooks/ops/<job>.yml` (parameterised with `-e`, documented in its header comment).

## 4. Break-glass (kind 4)

1. Fix by hand, minimal and reversible. Write down every command as you run it.
2. Within the same session: either **codify** the fix in the repo and run `make check` to
   confirm the repo now matches the host (no diff), or **revert** the manual change and
   apply the repo state.
3. Note what happened in the commit message or an incident note.

A manual change left un-codified is drift: the next `make apply` silently undoes it, or
worse, the next rebuild lacks it.

## 5. Safety practices

- **Blast radius**: always know `LIMIT` and `TAGS` before applying. Running `site.yml` on
  everything is for converging a known-clean state, not for testing a change.
- **Canary & serial**: roll risky changes to one host, verify, then the rest.
  Plays touching clusters use `serial: 1` (or a small number).
- **Idempotency**: a second `make apply` should report no changes. If it does, the role or
  your task is not idempotent — fix it.
- **Backups before destruction**: before data-affecting changes (DB upgrades, volume moves,
  uninstall), take and verify a backup (ideally an ops playbook).
- **Rollback**: `git revert <commit>` + apply. Keep changes small so reverts are clean.
  Some changes are not reversible by re-applying (data migrations, deleted volumes) —
  call that out before applying.
- **Lockout**: SSH/firewall/user/network changes — see security.md §11.

## 6. Drift detection

Run `make check` periodically (or in CI with read-only credentials). Any diff means the
servers differ from the repo: someone changed a host by hand, or the repo changed without
being applied. Resolve every drift into the repo, never by ignoring it.

## 7. Day-2 routine

| Task | How |
|---|---|
| OS packages security updates | kind 2 ops playbook (`ops/upgrade.yml`) with `serial`, reboot if required |
| Bump a component version (k3s, docker, exporter, image tag) | kind 3: change the version var → check → canary → rest |
| Rotate a secret | edit vault → apply roles that consume it → verify → revoke the old one |
| Certificates | `acme` role renews when within `acme_renew_days`; run `make run PLAY=<web> TAGS=acme` on a schedule or in CI |
| Add a host | add to `hosts.yml` + group → host_vars/vault → `make apply LIMIT=<new-host>` |
| Decommission a host | stop/remove workloads (e.g. k3s drain/uninstall) → remove from inventory → remove DNS → revoke keys/secrets it held |

## 8. Deploying apps from CI

Application repos can deploy themselves using the collection's Docker image
`ghcr.io/ahmz1833/server-setup:<version>` and the `apps` role with
`apps_preserve_mode: true` (update one app's image without touching others). The CI
job gets an SSH deploy key and the vault password of a **deploy-scoped** vault
(see security.md §3, multiple vault IDs). See `examples/fleet/ci/` for a template.

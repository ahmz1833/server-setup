# IaC project standard

How an infrastructure repository built on `ahmz1833.server_setup` is laid out and written.
The goal is a repo that a human can read top-to-bottom in ten minutes and an AI agent can
change without guessing.

> Related: [security.md](security.md) · [operations.md](operations.md) ·
> [debugging.md](debugging.md) · [toolchain.md](toolchain.md) · [roles-index.md](roles-index.md)

---

## 1. Principles

1. **The repo is the source of truth.** If it is not in git, it does not exist. Servers are
   cattle that the repo can rebuild.
2. **Assume the repo is public.** Anything that helps an attacker find, fingerprint or reach a
   system lives in an encrypted vault (see [security.md](security.md)).
3. **Boring and flat beats clever.** Plain YAML values over Jinja gymnastics; one obvious place
   for each setting; no layers of variable aliasing.
4. **The collection is mandatory where it applies.** Everything `ahmz1833.server_setup`
   *can* manage *must* be managed by it — users, SSH, firewall, sysctl, packages, Docker,
   containers, nginx sites, certificates, k3s, mail, sandboxes, proxies, exporters, binary
   installs (`asset`). No local role, `shell:`, template or other tool re-implements or
   overrides what a collection role owns, even if that looks simpler. Local roles and other
   tools are only for what the collection genuinely cannot do (§5) — and a missing *option*
   in a collection role is a feature request (upstream), not a reason to bypass the role.
5. **Every change is reviewable.** `make check` shows a diff before `make apply` changes
   anything.

---

## 2. Layout

```
my-infra/
├── AGENTS.md                 # project-specific notes for AI agents + humans (short)
├── CLAUDE.md                 # one line: @AGENTS.md
├── README.md                 # what this infra is, how to run it
├── Makefile                  # the only entry point you need to remember
├── ansible.cfg
├── requirements.yml          # collections (server_setup + deps)
├── requirements.txt          # python deps (ansible-core, passlib, …)
├── .gitignore                # .venv/, collections/, .vault_pass*, *.retry
├── inventories/
│   └── <env>/                # prod, staging, lab … (one is fine)
│       ├── hosts.yml         # hosts and groups only – no variables
│       ├── group_vars/
│       │   ├── all/
│       │   │   ├── main.yml          # env-wide settings (plain)
│       │   │   ├── vault.yml         # env-wide secrets (ENCRYPTED, auto-loaded)
│       │   │   └── vault.yml.example # same keys, fake values, committed in clear
│       │   └── <group>/              # one dir per functional group
│       │       ├── main.yml
│       │       └── vault.yml         # optional
│       └── host_vars/
│           └── <host>/
│               ├── main.yml
│               └── vault.yml         # host secrets: address, ports, credentials
├── playbooks/
│   ├── site.yml              # converge everything (imports the others)
│   ├── <concern>.yml         # base.yml, web.yml, apps.yml, k3s.yml …
│   └── ops/                  # reusable operational jobs (restart, reboot, backup, …)
├── roles/                    # optional: project-local roles
├── files/                    # optional: project-local static files and data
│   (playbooks/templates/)    # optional: templates used by plays (searched automatically)
└── collections/              # installed by `make setup` (gitignored)
```

Small projects may drop `<env>/` nesting if there will only ever be one environment, but
starting with `inventories/prod/` costs nothing and makes adding `staging` trivial.

### `hosts.yml`

Hosts and group membership only. Hosts are referenced by a **logical name**; the real
address comes from vault (`ansible_host: "{{ vault_ansible_host }}"` in
`host_vars/<host>/main.yml`) or from your `~/.ssh/config` alias.

```yaml
all:
  children:
    web:
      hosts:
        web-1:
    db:
      hosts:
        db-1:
```

### Groups

- Name groups by **function**: `web`, `edge`, `k3s_servers`, `k3s_agents`, `mail`,
  `monitoring`, `proxy`. Not by variant (`cf1`, `cf2`) or by person.
- Location/provider groups are fine as a second axis when they carry real settings
  (`loc_iran` sets `is_iran: true`, mirrors, NTP).
- A host gets a feature by being in the group that enables it. Keep the mapping obvious.

### Variables

- **Set collection variables directly**, under their real names (`nginx_sites`,
  `core_firewall_rules`, `apps_list`). Look them up in [roles-index.md](roles-index.md).
- The **only** indirection allowed is for sensitive values:
  `core_ssh_port: "{{ vault_ssh_port }}"`. The plain file shows *what* is configured;
  the vault holds the *value*.
- Put a value at the **broadest scope where it is true**: `all` → group → host.
  Do not copy the same value into five host files.
- When a value is a list that several scopes contribute to (e.g. firewall rules), prefer
  defining it once per scope it really belongs to; if you must merge, use a single,
  commented merge expression in one place.
- Split a vars file into `NN-topic.yml` pieces only when it grows past ~150 lines.

### Playbooks

- `site.yml` imports the concern playbooks in dependency order. Running it converges
  everything.
- Each play: explicit `hosts:` (a group), `become: true`, roles with a **tag equal to the
  role name** (`tags: [core]`). Collection roles also expose finer tags (`core-ssh`,
  `nginx-sites`, …) — see roles-index.
- Typical order: `core` → `acme` (certs before services that need them) → `node`
  (Docker, tooling) → `nginx` → `apps` / `mail` / `k3s` / `sandbox`.
- `playbooks/ops/<job>.yml`: small, parameterised, idempotent-where-possible jobs that are
  run on demand (`restart.yml -e service=nginx`, `reboot.yml`, `backup-<thing>.yml`).
  If you did something by hand twice, it becomes an ops playbook.

### Local roles

- `roles/<name>/` with `defaults/main.yml`, `tasks/main.yml`, a short `README.md`.
  Prefix variables with the role name.
- If the role is generic (useful outside this project), mark it with a
  `# UPSTREAM-CANDIDATE: <reason>` comment at the top of `tasks/main.yml` and open an issue
  or PR on the collection.

### Makefile

One small Makefile is the human and AI entry point (copy it from `examples/starter`).
Standard targets:

| Target | Does |
|---|---|
| `make help` | list targets |
| `make setup` | install/upgrade toolchain + latest collection (see [toolchain.md](toolchain.md)) |
| `make skills` | (re)install the AI agent skills user-wide (`setup` does it when missing) |
| `make docker-logs H=<h> [C=<c>]` | container list / logs on a host (read-only) |
| `make shell` / `make shell -- <cmd>` | subshell or one command with the project toolchain, inventory and vault ids set (`CMD='…'` when args contain `=` or quotes) |
| `make validate` | check vars against the roles' argument specs, offline |
| `make check` | `site.yml --check --diff` (dry-run) |
| `make apply` | `site.yml` for real |
| `make run PLAY=<p>` | run `playbooks/<p>.yml` (also `PLAY=ops/restart`) |
| `make ping` / `make graph` | connectivity / groups and hosts |
| `make vault-init/edit/view/check` | manage vault files |
| `make vault-keys` / `make vault-gen KEY=…` | list vault key names only / add a random secret without printing it |
| `make host H=<h>` | resolved vars of a host (`vault_*` values hidden unless `SHOW_VAULT=1`) |
| `make lint` | `ansible-lint` + `yamllint` |

Every playbook target honours `ENV=<env> LIMIT=<pattern> TAGS=<t> EXTRA="<args>"`.

### `ansible.cfg`

```ini
[defaults]
inventory = inventories/prod
collections_path = ./collections
roles_path = ./roles
stdout_callback = default
result_format = yaml
retry_files_enabled = False
interpreter_python = auto_silent

[ssh_connection]
pipelining = True
```

`become` is set per play, not globally. No absolute paths anywhere in the repo.

### `AGENTS.md`

Short (≤ 80 lines). Starts with the **agent skills** section from the starter (how an
agent installs `infra-iac` on a fresh machine), then only what is specific to *this* project: what it runs, environments,
groups and what they mean, non-obvious decisions, things that must never be done
(e.g. "never apply `k3s` to `prod` without `serial: 1`"). General rules live in the
`infra-iac` skill and these docs; link to them, do not copy them.

---

## 3. Writing style

- Comments explain **why**, not what: `# sing-box off: mail host must egress directly for SPF`.
- Booleans are `true`/`false`. Quote strings that look like numbers or contain `:`.
- Keep templates (`.j2`) for files; do not build YAML structures from templates
  (`lookup('template') | from_yaml`) unless there is no alternative — it hides data.
- Prefer collection features over `shell:`/`command:`. When `shell` is unavoidable, make
  it idempotent (`creates:`, `changed_when:`) and explain why in a comment.
- Secrets never in task names, `debug:` output or commit messages. Use `no_log: true` on
  tasks handling them.

---

## 4. Working in a repo that does not follow this standard

Many existing repos have their own layout. When you (human or agent) work in one:

1. **Detect its conventions first**: inventory location, how vars are split, how the vault
   is loaded, entry points (Makefile/scripts), tags. Read its README/AGENTS.md.
2. **Follow them** for the change at hand. A consistent repo in an odd style beats a repo
   in two styles.
3. **Do not restructure** as a side effect of an unrelated change. Propose structural
   improvements separately (as a list, or as their own commits when asked).
4. **Security problems are the exception**: plaintext secrets or exposure-sensitive values
   (see [security.md](security.md)) are reported immediately and fixed when the user
   agrees.
5. If the repo has no `AGENTS.md`, offer to add one describing what you learned.

---

## 5. Beyond the collection: other IaC in the same repo

The collection covers the server baseline and common services, and **whatever it can manage
must be managed by it** (principle 4). Real projects also need things it does not do — that
is normal, and they are still IaC with the same rules (in git, reviewed with a diff, secrets
vaulted, idempotent, documented).

### First: can the collection do it?

Before writing anything outside the collection:

1. Search [roles-index.md](roles-index.md) and the role READMEs/`defaults/main.yml` for the
   behaviour (many things are a toggle or a list item: `core_cron_jobs`, `core_ipsets`,
   `core_sysctl_extra`, `apps_list`, `nginx_sites[].extra_config`, `asset` for any binary…).
2. **Can do it** → use it. Full stop.
3. **Almost** (missing option/edge case) → use the role for everything it covers; add the
   smallest possible complement that does not touch files/resources the role manages; and
   record an upstream request (`# UPSTREAM: <feature>` comment + issue/PR via the
   server-setup-dev skill). If the complement would have to fight the role (edit its config
   files, re-template its services), extend the collection instead.
4. **Cannot** (outside its scope) → pick a tool from the table below.

Never manage the same resource from two places (e.g. a hand-written vhost while
`nginx_managed: true` removes unmanaged sites; iptables rules outside `core_firewall_rules`;
containers outside `apps_list` that `apps_prune` may delete).

### Choosing the tool

| Need | Prefer | Notes |
|---|---|---|
| Something on the hosts the collection has **no** role/option for (desktop/lab setup, a custom daemon, user data import) | **local Ansible role** in `roles/` | defaults + tasks + README; generic ones are upstream candidates |
| A one-off but repeatable job | `playbooks/ops/<job>.yml` | parameterised with `-e` |
| DNS records | `community.general.cloudflare_dns` (or your provider's module) in a `playbooks/dns.yml`; or OpenTofu/Terraform if you already manage the provider there | record **names** of public services can be plain; tokens vaulted; internal records → vault the names/targets |
| Cloud resources (VMs, networks, firewalls, buckets) | **OpenTofu/Terraform** in `terraform/` (or `tofu/`) with remote, encrypted state | Ansible configures what Terraform creates; outputs → inventory (never commit state files — they contain secrets/IPs) |
| Kubernetes workloads | manifests / Helm values in `k8s/` (or a separate GitOps repo), applied with `kubernetes.core.k8s` / `kubernetes.core.helm` from a playbook, or Argo CD/Flux | k3s *nodes* stay with the collection's `k3s` role |
| Machine images / first boot | cloud-init user-data or image build (Packer) in the repo | keep it minimal; converge with Ansible after boot |
| Data inputs (user lists, seat maps, DNS zones) | files under `files/` or vars files; CSV only if a non-technical person maintains it | personal data and passwords are vault material — never plain CSV in git |
| Third-party Ansible content | add to `requirements.yml` with a version, read what it does first | never for something `server_setup` already covers |

### Rules for non-collection IaC

- One clear home per tool: `roles/`, `playbooks/`, `terraform/`, `k8s/` — mention each in
  AGENTS.md with how to run it (add `make` targets for anything run regularly, e.g.
  `make dns`, `make tf-plan`).
- Same workflow: plan/diff (`--check --diff`, `tofu plan`, `helm diff`/`kubectl diff`) →
  confirm → apply → verify.
- Same secret discipline: provider tokens, kubeconfigs, Terraform state and `.tfvars` with
  secrets never in plain git; use ansible-vault, SOPS, or the tool's encrypted backend.
- Same exposure/attack-surface thinking: cloud security groups, DNS records that reveal
  internal services, LoadBalancer services in k8s are all attack surface.
- Keys are never files in the repo in clear: private SSH keys, TLS keys and keystores go into
  a vault (`copy: content="{{ vault_x }}"`) or are generated on the host.

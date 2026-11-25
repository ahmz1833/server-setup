---
name: infra-bootstrap
description: Create a new infrastructure-as-code project (Ansible + ahmz1833.server_setup collection) for a server, a set of servers, a cluster, or a new organization/startup/event - from an interview to a runnable, vaulted, validated repo. Use when the user wants to set up, provision or bootstrap new servers/infrastructure and there is no IaC repo for it yet, or asks for a new infra repo. For changing an existing project use infra-iac instead.
---

# Bootstrap a new IaC project

Goal: a small, readable repo in the standard layout that the user (with or without AI)
can run with `make`, with every sensitive value vaulted and the attack surface minimal
from day one. The `infra-iac` skill's golden rules apply throughout — read its
`references/security.md` and `references/iac-standard.md` if available.

## 1. Interview (short — infer what you can, ask only what you can't)

Ask in one message, offering sensible defaults:

1. **Purpose**: what will run? (websites/apps, APIs, k3s cluster, mail, proxy/relay,
   sandboxes, monitoring, CI runners …)
2. **Hosts**: how many, roles of each, OS (Debian/Ubuntu assumed), provider/location
   (Iranian network → `is_iran: true`), how you reach them (direct/bastion/VPN). Addresses,
   SSH ports and usernames are vault material — the user enters them, not the chat.
3. **Environments**: just `prod`, or `staging` + `prod`?
4. **Domains**: public service domains; DNS provider (Cloudflare → DNS-01 automation,
   wildcards); should DNS records / cloud resources (VMs, firewalls) also be managed as code?
5. **Access & trust**: is SSH/API restricted to an admin network, is there a monitoring
   server, who else needs access? (Only whether — the actual CIDRs/IPs go into the vault by
   the user.)
6. **Where the repo lives** (path) and whether it will be on a shared/public git host.

Never ask the user to paste secrets — or real IPs, SSH ports, internal hostnames, admin
usernames — into the chat. You write placeholders (`*.example`, `vault_*` references);
the user types real values via `make vault-edit`; random secrets come from
`make vault-gen KEY=…`. See `infra-iac` → "Secrets: you never see them".

## 2. Scaffold

1. Pick the closest starting point:
   - **`assets/starter/`** (bundled with this skill): single environment, one `web` host,
     core + node(docker) + acme + nginx + apps. Right for most single servers.
   - Larger patterns, from the collection's `examples/` (after setup:
     `collections/ansible_collections/ahmz1833/server_setup/examples/`, or
     `git clone --depth 1 https://github.com/ahmz1833/server-setup` into a temp dir):
     `multi-env-cluster` (staging/prod, per-env vault ids, k3s HA, mail, local role,
     vaulted `vault_hosts` map) and `fleet` (many unrelated servers, function + location
     groups, per-host sites, CI app deploys).
   Combine patterns as needed; the examples are references, not templates to keep intact.
2. Copy into the target directory (never overwrite existing files without asking):
   `cp -r <skill>/assets/starter/. <target>/` (includes dotfiles: `.gitignore`,
   `.yamllint`, `.ansible-lint`).
3. Shape it to the interview:
   - `inventories/<env>/hosts.yml`: **function** groups (`web`, `k3s_servers`, `mail`, …)
     and logical host names. No addresses here.
   - Few hosts → `host_vars/<host>/vault.yml(.example)` for address/port. Many hosts →
     one vaulted `vault_hosts` map in `group_vars/all` (see multi-env-cluster).
   - Enable only the features needed. Look up variables in `infra-iac`'s
     `references/roles-index.md` (or `ansible-doc -t role ahmz1833.server_setup.<role>`).
     Delete unused playbooks/vars rather than leaving dead config.
   - Firewall: one rule per real need, each with a `comment`; management/monitoring ports
     with `src:` restricted (vaulted CIDR).
   - Second environment? Copy `inventories/prod` → `inventories/staging`, same groups.
   - Everything the collection can manage is configured through its roles — no local
     re-implementations. Only needs it truly can't cover (DNS records, cloud resources, k8s
     workloads, host setup with no matching role/option): add them with the tool in `iac-standard.md` §5 — local role,
     `playbooks/dns.yml` with the provider module, `terraform/`, `k8s/` — each with a
     `make` target and a line in AGENTS.md.
4. Fill `AGENTS.md` and `README.md`; remove the `<placeholders>`. **Keep the "Agent
   skills (install if missing)" section** — it makes any agent on a new machine install
   these skills (`make skills`) before touching the infra. Add only
   project specifics below it.
5. `git init` if not inside a repo (ask first if the location is ambiguous).

## 3. Make it run

```bash
make setup                       # ansible (.venv if needed) + latest collection
make vault-init                  # or: make vault-init ENV=<env> VAULT_PER_ENV=1 (per-env passwords)
# random secrets (never printed), e.g. a k3s token:
make vault-gen KEY=vault_k3s_token
# the USER fills real values (give an explicit hand-off per file and key):
make vault-edit FILE=inventories/prod/group_vars/all/vault.yml
make vault-edit FILE=inventories/prod/host_vars/<host>/vault.yml
make vault-keys                  # you verify key names only
make validate                    # offline: vars vs role argument specs
make lint
make ping
make check LIMIT=<host>
```

- Tell the user to store the generated `.vault_pass*` in their password manager.
- They must put their **public** key in `files/ssh_keys/admin.pub`.
- First apply on a fresh host usually connects as root or the provider's default user:
  `make apply LIMIT=<host> EXTRA="-u root"` (confirm first). It creates the admin user,
  hardens SSH and enables the firewall — follow the lockout precautions (keep a session
  open, verify a new login before closing).

## 4. Finish

- Exposure & security review of all files (security.md §12): no real IPs, ports, internal
  names or usernames outside vaults; every open port justified; admin UIs on loopback.
- `make vault-check` passes; `.gitignore` covers `.venv/ collections/ .vault_pass*`.
- Summarize for the user: layout, how to run common tasks (`make help`), what's vaulted,
  security posture (what's exposed and to whom), next steps (DNS records, PTR for mail,
  monitoring hookup).
- Offer an initial commit (only commit when they agree).

From here on, the **infra-iac** skill handles changes and operations.

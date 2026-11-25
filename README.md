# Ansible collection: `ahmz1833.server_setup`

Roles for **Debian/Ubuntu**-style hosts: base hardening, edge Nginx (optional ModSecurity), TLS automation, Docker workloads, and optional SSH-into-container sandboxes. Binaries and static bundles are installed through a shared **`asset`** role used internally by **`node`**, **`nginx`**, and **`k3s`**.

**Galaxy namespace:** [`ahmz1833`](https://galaxy.ansible.com/ui/namespaces/ahmz1833/) · **Collection name:** `server_setup` · **FQCN prefix:** `ahmz1833.server_setup.<role>`

Beyond roles, this repo ships an **infrastructure-as-code standard**, **full example projects**, and **AI agent skills** so that servers can be bootstrapped, changed, operated and debugged - by a human or an agent - while everything stays in code, secrets stay in vaults and the attack surface stays small.

| Start here | |
|---|---|
| New infrastructure project | [`examples/starter`](examples/starter) → copy, `make setup`, `make vault-init` |
| Project standard (layout, rules) | [`docs/iac-standard.md`](docs/iac-standard.md) |
| Security (public-repo + attack-surface threat models) | [`docs/security.md`](docs/security.md) |
| Operating & changing infra | [`docs/operations.md`](docs/operations.md) · [`docs/debugging.md`](docs/debugging.md) |
| Running without Ansible installed | [`docs/toolchain.md`](docs/toolchain.md) |
| Every role variable | [`docs/roles-index.md`](docs/roles-index.md) (generated from argument specs) |
| Using an AI agent | [Using with AI agents](#using-with-ai-agents) |

---

## Using with AI agents

Four skills (in [`skills/`](skills)) teach an agent to work this way:

| Skill | For |
|---|---|
| **`infra-iac`** | any request touching servers or an infra repo: inspect/debug, one-off jobs, persistent changes through IaC, security review |
| **`infra-bootstrap`** | creating a new IaC project from an interview |
| **`server-setup-dev`** | developing this collection, or upstreaming a local role |
| **`server-diagnostics`** | availability & performance debugging using all available metrics/logs; benchmarks, network tests (iperf3), IP reputation — ephemeral, no trace |

Install (no clone of this repo needed):

```bash
# Claude Code plugin
/plugin marketplace add ahmz1833/server-setup
/plugin install server-setup@server-setup
# or: /plugin install server-setup --marketplace ahmz1833/server-setup

# Any agent supported by the skills CLI (Claude Code, Codex, Cursor, …)
npx skills add ahmz1833/server-setup            # all skills
npx skills add ahmz1833/server-setup --skill infra-iac
```

The skills are self-contained (bundled references and the starter project) and install Ansible plus the latest collection on demand. Projects created from the starter also carry an `AGENTS.md`/`CLAUDE.md`, so agents pick up the rules even without the skills.

---

## Start a project

```bash
cp -r examples/starter ~/infra/my-project && cd ~/infra/my-project   # or let infra-bootstrap do it
make setup        # ansible (.venv if needed) + latest collection into ./collections
make vault-init   # encrypted vault files from *.example, generates .vault_pass
make vault-edit   # real values (admin user, addresses, ports …)
make validate     # offline: vars vs role argument specs
make check LIMIT=web-1 && make apply LIMIT=web-1
```

| Example | Shows |
|---|---|
| [`examples/starter`](examples/starter) | single server: core, node (docker), acme, nginx + WAF, apps; ops playbooks |
| [`examples/multi-env-cluster`](examples/multi-env-cluster) | staging/prod with per-env vault ids, k3s HA, mail, source-restricted management, local role |
| [`examples/fleet`](examples/fleet) | heterogeneous servers, function + location groups, relay, sandboxes, monitoring, CI app deploys |

No Python on the machine? `make docker-shell` runs everything in
`ghcr.io/ahmz1833/server-setup:<version>` (ansible + this collection + dependencies).

---

## Requirements

| Requirement | Notes |
|-------------|--------|
| **Ansible** | `ansible-core` 2.15+ (`meta/runtime.yml`); examples pin 2.16–2.19 |
| **Python**  | 3.9+ on the controller |
| **Targets** | Roles are written for **systemd**-based Linux; several roles assume **Debian/Ubuntu** packages or paths—see each role README. |

### Collection dependencies

Declared in `galaxy.yml`; install with the collection or via `ansible-galaxy collection install -r requirements.yml`:

| Collection | Purpose (examples) |
|------------|---------------------|
| `community.general` | `archive`, and other helpers |
| `community.crypto` | TLS / crypto (e.g. ACME) |
| `community.docker` | `docker_container`, `docker_network`, … |
| `ansible.posix` | `sysctl`, `authorized_key`, … |
| `ansible.utils` | IP / text utilities where used |

---

## Installation

### From Ansible Galaxy (after publish)

```bash
ansible-galaxy collection install ahmz1833.server_setup
```

Pin a version:

```bash
ansible-galaxy collection install ahmz1833.server_setup:==1.5.0
```

### From Git

`requirements.yml`:

```yaml
---
collections:
  - name: https://github.com/ahmz1833/server-setup.git
    type: git
    version: master
```

```bash
ansible-galaxy collection install -r requirements.yml
```

Use your repository’s default branch (`main`, `master`, or a tag) for `version`.

### Build and install from a checkout

```bash
cd /path/to/server-setup
ansible-galaxy collection build
ansible-galaxy collection install ahmz1833-server_setup-<version>.tar.gz
```

The artifact name is **`{namespace}-{name}-{version}.tar.gz`**.

### Publishing to Galaxy (maintainers)

1. Bump **`version`** in `galaxy.yml` (semantic versioning).
2. `ansible-galaxy collection build`
3. `ansible-galaxy collection publish ahmz1833-server_setup-<version>.tar.gz --token <GALAXY_API_TOKEN>`

Ensure the **`namespace`** in `galaxy.yml` matches your Galaxy namespace (**`ahmz1833`**).

GitHub Actions now automates this flow:

- Pull requests and pushes to **`master`** run linting plus a build/install smoke test.
- Tag pushes publish to Galaxy after verifying the tag matches the **`galaxy.yml`** `version`.
- Set the repository secret **`GALAXY_API_TOKEN`** for publishing.

---

## Roles overview

| Role | Purpose |
|------|---------|
| **`ahmz1833.server_setup.core`** | Timezone, APT mirrors, packages, users, SSH hardening, iptables/nftables-style firewall, sysctl, fail2ban. |
| **`ahmz1833.server_setup.node`** | Sing-box, GOST, X-UI, Docker (static engine + plugins), shell tools, `node_exporter`; uses **`asset`** for downloads. |
| **`ahmz1833.server_setup.nginx`** | Debian Nginx, ModSecurity CRS, vhosts from `nginx_sites`, exporter/Promtail optional; depends on **`asset`**. |
| **`ahmz1833.server_setup.acme`** | Let's Encrypt via DNS-01 (manual or Cloudflare API) / HTTP-01; controller-side keys. |
| **`ahmz1833.server_setup.apps`** | Declarative `docker_container` stacks: deps, health wait, preserve mode, optional prune. |
| **`ahmz1833.server_setup.sandbox`** | SSH on a dedicated port into per-user Docker sandboxes (`blockinfile` on `sshd_config`). |
| **`ahmz1833.server_setup.k3s`** | Composable, property-driven K3s cluster provisioning, Day 0/1/2 lifecycle, firewall isolation, and host Nginx coexistence. |
| **`ahmz1833.server_setup.mail`** | Docker-based mail server (DKIM/DMARC/SPF), SSoT user management, and SnappyMail. |
| **`ahmz1833.server_setup.asset`** | Generic download / extract / install helper (binaries, files, packages); dependency of other roles. |

Each role has its own **`roles/<name>/README.md`** and **`meta/argument_specs.yml`**
(validated at runtime; `ansible-doc -t role ahmz1833.server_setup.<role>`). All variables
in one place: [`docs/roles-index.md`](docs/roles-index.md).

---

## Quick examples

### Core

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz1833.server_setup.core
      vars:
        is_iran: false
        core_manage_users: true
        core_manage_ssh: true
        core_manage_firewall: true
```

### Node

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz1833.server_setup.node
      vars:
        node_docker_enabled: true
        node_gost_enabled: true
        node_exporter_enabled: true
```

### Nginx

```yaml
- hosts: edge
  become: true
  roles:
    - role: ahmz1833.server_setup.nginx
      vars:
        nginx_managed: true
        nginx_sites:
          - domain: example.com
            ssl_enabled: true
            upstream: "http://127.0.0.1:8080"
```

### ACME

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz1833.server_setup.acme
      vars:
        acme_account_email: admin@example.com
        acme_certificates:
          - domains:
              - example.com
              - "*.example.com"
```

### Apps (`apps_list`)

```yaml
- hosts: app_servers
  become: true
  roles:
    - role: ahmz1833.server_setup.apps
      vars:
        apps_list:
          - name: web
            image: nginx:alpine
            ports:
              - "8080:80"
```

### Sandbox

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz1833.server_setup.sandbox
      vars:
        sandbox_ssh_port: 2222
        sandbox_users:
          - name: guest1
            ssh_keys:
              - "ssh-ed25519 AAAA... your-key"
            image: ubuntu:24.04
```

Connect as **`sandbox@host`** (or your `sandbox_shared_user`) on **`sandbox_ssh_port`**; see the sandbox role README.

### Mail

```yaml
- hosts: mail_servers
  become: true
  roles:
    - role: ahmz1833.server_setup.mail
      vars:
        mail_domain: "example.com"
        mail_hostname: "mail.example.com"
        mail_admin_username: "admin"
        mail_admin_password: "{{ vault_mail_admin_password }}"
```

### K3s

```yaml
- hosts: k3s_servers:k3s_agents
  become: true
  roles:
    - role: ahmz1833.server_setup.core
    - role: ahmz1833.server_setup.k3s
      vars:
        k3s_state: present
```

---

## Cross-role playbook variables

Set at play, group, or host level when you want shared behavior:

| Variable | Typical use |
|----------|-------------|
| `is_iran` | **`core`**: timezone/mirrors; **`node`**: `node_internet_restricted`; **`nginx`**: `nginx_download_locally` (via default expression). |
| `enable_ipv6` | **`core`**: sysctl/firewall IPv6; **`nginx`**: `listen [::]:…` when enabled. |
| `primary_user` | **`core`**: `core_primary_user` (protected user, SSH keys). |
| `download_locally` | **`node`**: fetch artifacts on the controller / cache (`node_download_locally`); also referenced by roles that pass it into **`asset`**. |

Exact wiring is in each role’s `defaults/main.yml`.

---

## Repository layout

| Path | What |
|---|---|
| `roles/` | `core`, `node`, `nginx`, `acme`, `apps`, `sandbox`, `k3s`, `mail`, `asset` (each with README, defaults, argument specs, optional `examples/`) |
| `docs/` | IaC standard, security, operations, debugging, toolchain, generated roles index |
| `examples/` | complete example projects (`starter`, `multi-env-cluster`, `fleet`) |
| `skills/` | AI agent skills (`infra-iac`, `infra-bootstrap`, `server-setup-dev`, `server-diagnostics`) |
| `scripts/` | `ensure-toolchain.sh` (project setup), `gen-roles-index.py`, `sync.sh` (propagates docs/starter into skills and examples) |
| `.claude-plugin/` | Claude Code plugin + marketplace manifests |
| `Dockerfile` | runner image `ghcr.io/ahmz1833/server-setup` (ansible + this collection) |
| `galaxy.yml`, `meta/` | collection metadata |

---

## License

MIT

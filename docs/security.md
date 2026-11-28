# Security guide

Two threat models, both always in force:

- **Part A — the repository leaks.** What an attacker learns from reading the IaC.
- **Part B — the running infrastructure is attacked.** What an attacker can reach and
  break on the servers, networks and services the IaC builds.

Humans and AI agents apply both when **designing**, **changing**, **operating** and
**reviewing** infrastructure — and must *warn* when something is weak, even if nobody
asked.

---

# Part A — Assume the repository is public

> **Threat model: assume the repository is public.**
> Maybe it is private today. Repos get forked, mirrored, leaked through CI logs, laptops and
> ex-collaborators. Write every file as if an attacker is reading it. From the repo alone an
> attacker must not be able to **find**, **fingerprint** or **reach** anything that is not
> already public by design — and certainly not to log in or act.

This guide is for humans and AI agents. It is a judgment guide, not a regex list: a tool
cannot know whether a domain is public or a port is meant to be hidden. You can.

---

## 1. The exposure question

For **every literal value** you write (or find) in a non-vault file, ask:

> *If an attacker read this line, would it help them find, fingerprint or reach
> something they could not trivially discover from the outside?*

- **Yes** or **not sure** → it goes into an encrypted vault, referenced by name.
- **No** (it is public by design, or meaningless without other secrets) → plaintext is fine.

"Trivially discover from the outside" means: it is in public DNS for a public service, it
is the standard port of a public service, or it is a generic setting that reveals nothing
about *your* systems.

## 2. Classification

### Always vault

| Kind | Examples | Why |
|---|---|---|
| Credentials | passwords, API tokens, private keys, kubeconfigs, registry auth, DB DSNs with passwords, TOTP seeds | direct access |
| Secret URLs | webhook paths with tokens (`/deploy/<random-token>`), signed URLs, hidden admin paths | a URL *is* a credential |
| Server addresses | public and private IPs, `ansible_host`, IPv6 prefixes, provider instance IDs | lets an attacker skip discovery and target hosts directly |
| Non-standard ports | custom SSH port, panel/admin UI ports, proxy/tunnel listen ports, management APIs | hiding them is the point of moving them |
| Internal names | hostnames/domains that are not public services (`panel.internal.x.com`, `db1.corp.x`), internal DNS zones | reveal topology and targets |
| Privileged identities | admin/sudo usernames, deploy user names, service account names that can log in | halves a brute-force |
| Topology hints | tunnel peers and endpoints, upstream/origin IPs behind a CDN, allow-listed CIDRs/IPs, VPN subnets that identify you, which host relays for which | maps the network and the trust graph |
| Personal data | emails of real people (except a role address that is public anyway), phone numbers | privacy, phishing |

### Usually plaintext

| Kind | Examples | Why it is OK |
|---|---|---|
| Public service domains | `grafana.example.com`, `www.example.com`, `api.example.com` that are in public DNS and serve the public | already public via DNS/CT logs |
| Standard ports of public services | 80, 443, 25/465/587/993 on a mail server | scanners find them in seconds anyway |
| Role toggles & tuning | `core_manage_firewall: true`, `nginx_waf_install: true`, sysctl values | generic |
| Versions & images | `k3s_version`, `image: nginx:1.27-alpine` | public; pinning is good practice |
| Generic internal ranges | default docker/k3s CIDRs (`10.42.0.0/16`, `172.29.0.1/16`) | identical on millions of hosts |
| Group/host **logical** names | `web-1`, `k3s_servers` | say what, not where |

### Judgment calls (decide, and say why)

| Value | Lean | Reasoning |
|---|---|---|
| Public domain of a service that *should* be hidden (`admin.example.com` behind IP allow-list) | vault | being in DNS doesn't mean you should advertise it's an admin panel |
| Origin IP of a site behind Cloudflare/CDN | vault | exposing it bypasses the CDN/WAF |
| Port 22 | plaintext ok | standard; but if you moved SSH, the new port is vaulted |
| Email for ACME account | plaintext ok if it is a role address (`ops@example.com`); vault if personal | |
| Exporter listen `127.0.0.1:9100` | plaintext | loopback reveals nothing |
| Firewall rule `port: 443` | plaintext | public service |
| Firewall rule `port: 8443, source: 203.0.113.7` | vault both the port and the source | management port + trusted IP |
| Registry hostname | plaintext if public registry; vault if private | |

**When unsure, vault it.** The cost of an extra vault variable is nothing; the cost of
a leak is unbounded and permanent (git history).

## 3. How to vault things

Use whole-file encrypted vault files that are auto-loaded by inventory placement:

```
inventories/prod/group_vars/all/vault.yml        # env-wide secrets
inventories/prod/group_vars/<group>/vault.yml    # group secrets
inventories/prod/host_vars/<host>/vault.yml      # host address, ports, credentials
```

Pattern: the plain file says **what**, the vault holds the **value**.

```yaml
# host_vars/web-1/main.yml (plain)
ansible_host: "{{ vault_ansible_host }}"
ansible_port: "{{ vault_ssh_port }}"
core_ssh_port: "{{ vault_ssh_port }}"

# host_vars/web-1/vault.yml (encrypted with ansible-vault)
vault_ansible_host: 198.51.100.24
vault_ssh_port: 22022
```

Rules:

- Vault variables are prefixed `vault_`. A plain variable references it by name.
- Encrypt **whole files** (`ansible-vault encrypt`), not inline `!vault` values — whole
  files hide the variable names too and are easier to review.
- Keep `vault.yml.example` next to each vault with the same keys and obviously fake
  values (`198.51.100.x`, `CHANGEME`), so people and agents know what exists.
- `make vault-check` fails if any `vault*.yml` (not `.example`) is not encrypted. Run it
  before every commit (the starter has a pre-commit hook snippet).
- Use RFC 5737/3849 documentation addresses (`192.0.2.0/24`, `198.51.100.0/24`,
  `203.0.113.0/24`, `2001:db8::/32`) and `example.com` in examples and docs.

### Multiple vaults / vault IDs

Use separate vault IDs when different people or pipelines may decrypt different things
(e.g. staging vs prod, or a CI deploy key that must not read infra root creds):

```
inventories/staging/group_vars/all/vault.yml   # encrypted with --vault-id staging@...
inventories/prod/group_vars/all/vault.yml      # encrypted with --vault-id prod@...
```

```bash
ansible-vault encrypt --vault-id prod@.vault_pass.prod inventories/prod/group_vars/all/vault.yml
ansible-playbook playbooks/site.yml -i inventories/prod --vault-id prod@.vault_pass.prod
```

The starter Makefile supports this via `VAULT_IDS` (see [toolchain.md](toolchain.md)):
`VAULT_IDS="prod@.vault_pass.prod"`; by default it uses `default@.vault_pass` if present,
else prompts.

(The sudo password works the same way: a gitignored `.become_pass` file — see
[toolchain.md](toolchain.md).)

Password sources, in order of preference: a password manager script
(`--vault-id prod@scripts/vault-pass-client.sh`), a gitignored file (`.vault_pass*`),
an environment variable in CI (write it to a temp file with mode 600), an interactive
prompt. Never commit a vault password, never echo it in CI logs.

**Never fall back** to `vault.yml.example` or to empty values when the real vault is
missing — fail loudly instead.

## 4. In tasks and templates

- `no_log: true` on tasks whose arguments or results contain secrets (user passwords,
  tokens, registry logins).
- Do not print secrets in `debug:`; do not put them in task names.
- Rendered files with secrets: `mode: "0600"` (or `0640` with a specific group), owned by
  the service user.
- Prefer passing secrets via files/env to containers over command-line args (visible in
  `ps`).

## 5. If something sensitive was committed

Deleting it in a new commit is **not** enough — it is in history and in every clone.

1. **Rotate** the secret / change the port / move the service (assume it is known).
2. Then move the value into the vault.
3. Optionally rewrite history (`git filter-repo`) — useful, but never a substitute for
   rotation.

## 5a. Secrets and AI agents — minimal exposure

Anything an AI agent reads (command output, files, chat) leaves your machine and may be
logged. Vault content falls into two classes with different rules for agents:

| Class | Examples | Agent may read? | Where it may appear |
|---|---|---|---|
| **Identifiers** | IP addresses, ports, domains/hostnames, usernames, CIDRs, provider/region | **yes**, when the task needs them (connectivity, debugging, `make ssh-config`, firewall reasoning) | vault, the user's local `~/.ssh/config`, the chat — **never** in plaintext repo files, commit messages or public places |
| **Credentials** | passwords, tokens, API keys, private keys, seeds/UUIDs used as secrets, secret URL paths, kubeconfigs, `.vault_pass*`, `.become_pass*` | **no** — never printed, never pasted into chat or command lines | only in vaults or the files their tools need on hosts; moved between vaults by pipe, never displayed |

The Makefile enforces the split: `make host` shows identifier values and hides credential
values; `make var` refuses credential-looking names. Classification is by key name
(identifier names like `*_ip`, `*_port`, `*_domain`, `*_user`, `address`, `ssh_port`); anything
not recognised as an identifier is treated as a credential.

**The agent must not:**

- ask you to paste a credential into the chat;
- view or decrypt whole vault files (`make vault-view`, `ansible-vault view|decrypt|edit`),
  or read `.vault_pass*`, `.become_pass*`/`.become-pass*`, kubeconfigs, private keys, `.env`
  files or Terraform state;
- print credential values (`make host … SHOW_VAULT=1`, `ansible -m debug` of credential
  variables, `env`, `docker inspect` of containers with secret env, `cat` of rendered config
  files containing credentials);
- put a credential into a command line (transcript, shell history), or an identifier into
  a plaintext repo file.

**Instead:**

| Situation | Do |
|---|---|
| A new credential is needed | wire it: `x: "{{ vault_x }}"` in the plain vars, `vault_x: CHANGEME` in `vault.yml.example`; then **ask the human** to add it (hand-off template below) |
| It can be random (passwords, tokens, API keys you define) | `make vault-gen KEY=vault_x FILE=<vault.yml> [LEN=32]` — generated and encrypted in one pipe, never printed |
| It comes from outside (provider API token, registry login, license key, a person's password) | hand-off to the human with exact instructions — or, if it already exists in another vault you may use, move it by pipe without printing |
| A new identifier (IP, port, domain) is needed | add it to the vault yourself if the user gave it to you or you read it from an existing vault; reference it as `vault_*` |
| Check what exists | `make vault-keys` (key names), `make host H=<h>` (identifiers visible, credentials hidden) |
| sudo needs a password | the human creates `.become_pass` (mode 600, gitignored); the Makefile passes it to every ansible command — the agent only checks the file exists (`test -s .become_pass`) |
| A secret is needed on the host as a file (key, cert) | `copy: content="{{ vault_x }}" mode=0600` with `no_log: true` — the human (or a pipe from another vault) puts the content in the vault |
| You pasted a credential into the chat anyway | the agent does not repeat it, tells you to put it in the vault yourself and suggests rotating it if it is sensitive |

**Hand-off template** (what the agent tells you, then waits for "done"):

```
🔐 Manual step — secrets stay out of the AI session
1. Run:  make vault-edit FILE=inventories/prod/group_vars/all/vault.yml
2. Add:  vault_cloudflare_api_token: "<your token>"
3. Where to get it: Cloudflare → My Profile → API Tokens → Create → "Edit zone DNS",
   zone example.com only.
(I referenced it as acme_cloudflare_api_token: "{{ vault_cloudflare_api_token }}" and added a
placeholder to vault.yml.example.) Tell me when done — I'll only check the key exists.
```

# Part B — Attack surface of the running infrastructure

Every open port, running service, account, credential and dependency is attack surface.
The goal: **expose the minimum, to the minimum set of sources, with the minimum
privilege, and notice when something goes wrong.**

## 6. Network exposure

| Principle | In practice (collection knobs) |
|---|---|
| **Default deny** | `core_manage_firewall: true`, `core_firewall_default_policy: DROP`. Every open port has a `comment:` that says why it exists. |
| **No unnecessary open ports** | Open only what the host *serves to the public*. Review `core_firewall_rules` on every change; remove rules for services that are gone. Verify from outside (`nmap -Pn <host>` from a trusted box) — not just by reading YAML. |
| **Restrict by source** | Management and internal ports are **never** world-open: SSH (`core_firewall_ssh_src` → office/VPN/bastion CIDR when possible), monitoring scrapers (node_exporter 9100, nginx exporter, cAdvisor, Prometheus, Loki/Promtail) → only the monitoring server's IPs (`src:` / `ipset:` in `core_firewall_rules`), DB/cache ports → only app hosts, k8s API 6443 → only admins/nodes. The allowed sources are themselves topology → vault them (Part A). |
| **Bind to loopback / private interface** | Containers publish `127.0.0.1:PORT:PORT` and sit behind nginx; exporters listen on `127.0.0.1` or a private/VPN interface; admin UIs (x-ui, panels, dashboards) are loopback-only and reached via SSH tunnel/VPN, or behind nginx with auth **and** allow-list. |
| **Docker bypasses host firewalls** | A container published on `0.0.0.0` is reachable even if `core_firewall_rules` does not list it (Docker's own iptables chains). Always publish on `127.0.0.1` unless it is a public service. |
| **One public entry point** | Public HTTP(S) goes through nginx (TLS, WAF, rate limits, real-IP handling). No app container exposed directly to the internet. |
| **Segment** | Separate Docker networks per stack (`apps_networks`, `internal: true` for backends), separate hosts for unrelated trust levels (public web vs. mail vs. CI runners vs. cluster control plane). |
| **CDN / origin** | If behind a CDN, allow 80/443 only from the CDN ranges (`ipset`) and keep the origin IP secret. Use `nginx_trusted_proxies` so logs and rate limits see real client IPs. |
| **Egress** | Consider what a compromised host can reach: limit outbound where practical (tunnels/proxies, SMTP from non-mail hosts). |
| **IPv6** | If enabled, it needs the same firewall rules — an open v6 is a common bypass (`enable_ipv6`, `src_v6`, `v4_only`/`v6_only`). |

## 7. Access and identity

- SSH: keys only (`core_ssh_password_auth: false`), no root login, `core_ssh_allow_users`
  set, `core_ssh_max_auth_tries` low, `fail2ban` on. Moving the port reduces noise, it is
  not a control.
- Least privilege: separate admin users (humans) from automation/deploy users; deploy users
  get only what CI needs (ideally not full sudo). `sudoer_no_pass` only for automation keys.
- Remove access promptly: offboarding = remove the key from `core_users` and apply
  everywhere; `core_users_whitelist` must stay minimal.
- Per-service credentials (no shared passwords between services/environments); rotate on
  suspicion and on staff change.
- Kubeconfigs, registry tokens, panel passwords, runner tokens are credentials (vault,
  `no_log`, file mode `0600`).

## 8. Services and workloads

- **TLS everywhere public** (`acme`), HTTP only for ACME + redirect. Keep modern protocols
  (`nginx_ssl_protocols` defaults). Consider a CAA DNS record.
- **WAF + rate limiting** for public apps (`nginx_waf_install`, per-site `waf_enabled`,
  `rate_limit` on login/API routes). Tune false positives per-rule, never by turning the
  WAF off globally.
- **Containers**: pin image tags (avoid `latest` for production), prefer official/trusted
  images, no `privileged`/host network/docker.sock mounts unless essential (and then note
  why), run as non-root where the image supports it, read-only volumes where possible,
  resource limits.
- **Admin & dangerous tools** (x-ui, sing-box/GOST panels, sandbox SSH, GitLab runners):
  isolate them — dedicated host or at least dedicated user/network, source-restricted
  ports, separate credentials. A CI runner that executes untrusted code must not share a
  host with production secrets.
- **Mail**: SPF, DKIM, DMARC published; no open relay; admin/webmail behind TLS and
  restricted where possible.
- **Kubernetes**: API restricted by source; no workloads in `kube-system` by habit;
  NetworkPolicies for sensitive namespaces; secrets not in plain manifests in git.

## 9. Patching, supply chain and detection

- **Patch**: OS security updates on a schedule (`playbooks/ops/upgrade.yml`, `serial`);
  bump component versions deliberately (k3s, docker, nginx, exporters, images).
- **Supply chain**: pinned versions in vars; downloads from official sources or trusted
  mirrors (the `asset` role); review what a new third-party role/collection/image does
  before adding it.
- **Detect**: logs kept and shipped (journald retention, `nginx_promtail_install`),
  metrics + alerts (node_exporter, nginx exporter), failed-login/fail2ban visibility,
  certificate-expiry alerts. A breach you cannot see lasts longer.
- **Recover**: backups of data and of the vault password; tested restores; the IaC itself
  is your rebuild plan.

## 10. Security duties of an agent (and of a reviewer)

When **designing** or **changing** anything:

1. Before adding an open port, ask: who needs to reach it? → public (open), specific
   systems (restrict `src`/`ipset`), only local (bind loopback, no firewall rule).
2. Prefer the safer design by default (loopback + nginx, allow-lists, separate users) and
   say why. If the user chooses a riskier option, implement it but state the risk once,
   clearly.
3. Never silently widen exposure (opening `0.0.0.0/0`, publishing a container on all
   interfaces, disabling WAF/fail2ban/firewall, enabling password auth). Call it out in the
   plan and in the summary.

When **operating** or **reading** an existing setup, report weaknesses you notice even if
unrelated to the task — briefly, with severity and a suggested fix:

```
⚠ Security notes
- HIGH  node_exporter :9100 open to 0.0.0.0/0 on web-1 → restrict to monitoring IPs (vault) or bind 127.0.0.1
- MED   app container published on 0.0.0.0:8080 (Docker bypasses host firewall) → 127.0.0.1:8080
- LOW   image nginx:latest in prod → pin a version
```

Do not fix unrelated findings without asking; do not bury them either.

## 11. Do not lock yourself out

Changes to SSH, firewall, users, or networking can cut your own access.

- Keep an existing SSH session open while applying; test a **new** session before closing.
- Changing the SSH port: open the new port in the firewall first, apply SSH, verify, then
  update inventory, then remove the old port.
- Apply to one host first (`LIMIT=<canary>`), then the rest (`serial` in the play).
- Know your out-of-band access (provider console/VNC) before touching firewall on a
  remote host.

# Part C — Before you finish

## 12. Exposure & security review (mandatory before finishing a change)

Before calling any change done (human PR or AI session):

1. `git diff` (and `git status` for new files) — read every added line.
2. For every new literal, apply the exposure question (§1). Move sensitive ones to vault.
3. Make sure no new `vault*.yml` is unencrypted (`make vault-check`), every new
   `vault_*` reference has a placeholder in `vault.yml.example`, and the real values were
   added by the human (`make vault-keys` shows the keys).
4. Check commit messages and new docs for the same leaks (IPs/ports in prose count!).
5. Attack surface (Part B): did this change open a port, publish a container, add a
   service, account or credential? Is each one restricted to who needs it?
6. Report: *"Vaulted: X (why), Y (why). Left plaintext: Z (public service domain).
   Surface: opened 443 (public), 9100 restricted to monitoring (vaulted CIDR)."*

When reading an existing repo for any task, note pre-existing exposures you notice and
report them; fix them when asked.

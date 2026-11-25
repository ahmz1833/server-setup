# AGENTS.md

Infrastructure-as-code for a **fleet of heterogeneous servers**: public websites, a relay,
sandboxes and a monitoring host. Built on
[`ahmz1833.server_setup`](https://github.com/ahmz1833/server-setup).

## Agent skills (install if missing)

This project is operated with the `infra-iac` skill (plus `server-diagnostics`,
`infra-bootstrap`, `server-setup-dev`) from [`ahmz1833/server-setup`](https://github.com/ahmz1833/server-setup).
**Agents: before doing any infra work, check that `infra-iac` is available to you. If not:**

1. Run `make skills` (= `npx -y skills add ahmz1833/server-setup -g -y --skill '*'`, installs
   user-wide for Claude Code, Codex, Cursor and other detected agents; `make setup` does it
   automatically when the skills are missing). Then reload skills / start a new session.
   Claude Code alternative: `/plugin install server-setup --marketplace ahmz1833/server-setup`.
2. No network/npx: read `collections/ansible_collections/ahmz1833/server_setup/skills/infra-iac/SKILL.md`
   (present after `make setup`) and follow it — same content.

## Rules (non-negotiable)

- **Everything is IaC**: edit → `make check LIMIT=<host>` → confirm → `make apply LIMIT=<host>` → verify.
- **Assume this repo is public**: addresses, SSH/relay/sandbox ports, the monitoring IP,
  credentials → `inventories/prod/group_vars/all/vault.yml`. Exposure + attack-surface review
  and `make vault-check` before committing.
- Always `LIMIT` applies in this fleet — hosts are unrelated to each other.


- **Agents never see credentials**: identifiers (IPs, ports, domains, users) may be read
  from the vault (`make host`); credentials never — no vault viewing/decrypting, never read
  `.vault_pass*`/`.become_pass*`. Wire `vault_*` references with placeholders and ask the
  human to fill them (`make vault-edit`), or `make vault-gen` for random ones.
- **Collection first**: anything `ahmz1833.server_setup` can manage is managed through its
  roles — never re-implemented locally or by hand.

## This project

- **Function groups**: `edge` (acme+nginx+apps), `proxy` (gost relay), `sandbox`,
  `monitoring` (Prometheus+Grafana containers). **Location groups**: `loc_iran`
  (`is_iran: true`, `download_locally: true`), `loc_abroad`.
- Per-site config (`nginx_sites`, `acme_certificates`, `apps_list`) lives in
  `host_vars/<edge-host>/main.yml`.
- Host addresses: vaulted map `vault_hosts`. Prometheus targets are generated from the
  inventory (`playbooks/templates/prometheus.yml.j2`).
- Apps are deployed by their own CI in preserve mode (`ci/gitlab-deploy.yml`); bump the
  pinned image here afterwards.

## Decisions & gotchas

- node_exporter listens on all interfaces but the firewall admits only `vault_monitoring_ip`.
- Prometheus is loopback-only; use `ssh -L 9090:127.0.0.1:9090 mon-1`.
- Relay requires auth; never configure it without `auths` (open proxy).

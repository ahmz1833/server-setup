# AGENTS.md

Infrastructure-as-code for **<project>**: a k3s cluster (3 control-plane + workers) and a
mail server, in two environments. Built on
[`ahmz1833.server_setup`](https://github.com/ahmz1833/server-setup).

## Agent skills (install if missing)

This project is operated with the `infra-iac` skill (plus `infra-bootstrap`,
`server-setup-dev`) from [`ahmz1833/server-setup`](https://github.com/ahmz1833/server-setup).
**Agents: before doing any infra work, check that `infra-iac` is available to you. If not:**

1. Run `make skills` (= `npx -y skills add ahmz1833/server-setup -g -y --skill '*'`, installs
   user-wide for Claude Code, Codex, Cursor and other detected agents; `make setup` does it
   automatically when the skills are missing). Then reload skills / start a new session.
   Claude Code alternative: `/plugin install server-setup --marketplace ahmz1833/server-setup`.
2. No network/npx: read `collections/ansible_collections/ahmz1833/server_setup/skills/infra-iac/SKILL.md`
   (present after `make setup`) and follow it — same content.

## Rules (non-negotiable)

- **Everything is IaC**: edit → `make check ENV=…` → confirm → `make apply ENV=… LIMIT=…` → verify.
- **Staging first**: every change is applied and verified on `ENV=staging` before `ENV=prod`.
- **Assume this repo is public**: addresses, admin/monitoring CIDRs, internal names,
  tokens and passwords live in `inventories/<env>/group_vars/all/vault.yml`.
  Exposure + attack-surface review of the diff and `make vault-check` before committing.
- Cluster changes on prod roll with `serial: 1` (see `playbooks/ops/k3s-upgrade.yml`).


- **Agents never see secret values**: no vault viewing/decrypting; wire `vault_*`
  references with placeholders and ask the human to fill them (`make vault-edit`), or use
  `make vault-gen` for random ones.
- **Collection first**: anything `ahmz1833.server_setup` can manage is managed through its
  roles — never re-implemented locally or by hand.

## This project

- **Environments**: `inventories/staging`, `inventories/prod` (default `ENV=prod`).
  Separate vault passwords: `.vault_pass.staging`, `.vault_pass.prod` (vault ids =
  env name). Create with `make vault-init ENV=<env> VAULT_PER_ENV=1`.
- **Groups**: `k3s_servers`, `k3s_agents` (children of `k3s_cluster`), `mail`.
- **Host addresses**: one vaulted map `vault_hosts` per env (address, private_ip, ssh_port).
- **Local roles**: `roles/journald` (log retention; upstream candidate).
- **Network policy**: SSH and the k8s API only from `vault_admin_cidr`; node_exporter only
  from `vault_monitoring_cidr` over the private network; public: ingress 80/443, mail ports.

## Decisions & gotchas

- `cp-1` is `cluster-init`; `cp-2/3` `join`. Never re-run cp-1 as cluster-init on a live cluster.
- Mail is outside the cluster on purpose (needs stable IP/PTR, port 25, simple restores).
- Day-2 node ops: `make run PLAY=ops/k3s-day2 LIMIT=<node> EXTRA="-e action=drain"`.

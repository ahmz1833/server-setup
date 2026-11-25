# AGENTS.md

Infrastructure-as-code for **<project name>**: <one line — what runs here and for whom>.
Built on the Ansible collection [`ahmz1833.server_setup`](https://github.com/ahmz1833/server-setup).

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

- **Everything is IaC.** Persistent changes go through this repo:
  edit → `make check` → confirm → `make apply LIMIT=…` → verify. Never change server state
  by hand except break-glass, and then codify or revert it in the same session.
- **Assume this repo is public.** IPs, non-standard ports, internal hostnames,
  privileged usernames, tokens and topology hints go in `vault.yml` files. Do an
  exposure review of your diff and run `make vault-check` before committing.
- **Agents never see secret values**: no vault viewing/decrypting; wire `vault_*`
  references with placeholders and ask the human to fill them (`make vault-edit`), or use
  `make vault-gen` for random ones.
- **Collection first**: anything `ahmz1833.server_setup` can manage is managed through its
  roles — never re-implemented locally or by hand.
- Read-only investigation is fine; state-changing one-off jobs use `playbooks/ops/` or are
  confirmed first.

## This project

- **Environments**: `inventories/prod` (default). <add staging if any>
- **Groups**:
  - `web` — public web/app servers: acme → nginx → docker apps on loopback.
- **Entry point**: `make help`. Typical: `make check LIMIT=web-1 TAGS=nginx`.
- **Secrets**: ansible-vault, password in `.vault_pass` (gitignored, kept in
  <password manager>). Keys are listed in each `vault.yml.example`.
- **Access**: <how you reach hosts: direct / bastion / VPN>.

## Decisions & gotchas

- <e.g. "app containers bind to 127.0.0.1 only; nginx is the single public entry">
- <e.g. "first apply on a fresh host must use EXTRA='-u root' (admin user doesn't exist yet)">

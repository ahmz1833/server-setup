# <project> infrastructure

Ansible IaC using [`ahmz1833.server_setup`](https://github.com/ahmz1833/server-setup),
laid out per the collection's [IaC standard](https://github.com/ahmz1833/server-setup/blob/master/docs/iac-standard.md).

## Quick start

```bash
make setup                 # installs ansible (if needed) + latest collection into ./collections
make vault-init            # creates encrypted vault.yml files from *.example (+ .vault_pass)
make vault-edit FILE=inventories/prod/host_vars/web-1/vault.yml   # real IP / port
make vault-edit            # env-wide secrets (admin user, …)
make vault-keys            # list key names (values never shown)
make vault-gen KEY=vault_x # add a random secret without printing it
cp ~/.ssh/id_ed25519.pub files/ssh_keys/admin.pub
make ping
make check                 # dry run with diff
make apply LIMIT=web-1     # first run on a fresh host: add EXTRA="-u root"
```

No Python/Ansible on this machine? `make docker-shell`, then the same `make` targets inside.

## Layout

| Path | What |
|---|---|
| `inventories/prod/hosts.yml` | hosts and groups |
| `inventories/prod/group_vars/all/` | env-wide settings (`main.yml`) and secrets (`vault.yml`) |
| `inventories/prod/group_vars/web/` | web servers: firewall, acme, nginx, apps |
| `inventories/prod/host_vars/<host>/` | per-host connection + overrides (vaulted) |
| `playbooks/site.yml` | converge everything (`base` → `web` → `apps`) |
| `playbooks/ops/` | on-demand jobs: restart, reboot, upgrade |

## Common tasks

| Want | Do |
|---|---|
| Add a site | add to `nginx_sites` + `acme_certificates` in `group_vars/web/main.yml` → `make check TAGS=acme,nginx` → `make apply TAGS=acme,nginx` |
| Add an app | add to `apps_list` → `make apply PLAY=apps` |
| Open a port | `core_firewall_rules` (vault non-standard ports) → `make apply TAGS=core-firewall` |
| Restart a service | `make run PLAY=ops/restart LIMIT=web-1 EXTRA="-e service=nginx"` |
| Upgrade OS | `make run PLAY=ops/upgrade LIMIT=web-1` |
| See a host's vars | `make host H=web-1` |
| Container logs | `make docker-logs H=web-1` (list) · `make docker-logs H=web-1 C=app SINCE=10m` |
| Command on servers | `make shell H=web -- df -h` · `make shell H=web-1 CMD='ss -ltnp \| grep 443'` |
| SSH into a server | `make shell H=web-1` (address/port/user come from inventory + vault) |
| Any module / a variable | `make module H=web-1 M=ansible.builtin.setup A='filter=ansible_mem*'` · `make var H=web-1 V=nginx_sites` |

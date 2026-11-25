# Example: a fleet of heterogeneous servers

Shows the [IaC standard](../../docs/iac-standard.md) for many unrelated hosts:

- **Two grouping axes**: function (`edge`, `proxy`, `sandbox`, `monitoring`) and location
  (`loc_iran` flips the collection's restricted-network behaviour).
- **Per-host specifics** in `host_vars/<host>/main.yml`, shared baseline in `group_vars/all`.
- **Least exposure**: every firewall rule has a reason; exporters admit only the monitoring
  host; admin UIs on loopback; the relay is authenticated on a vaulted port.
- **Project templates** (`playbooks/templates/prometheus.yml.j2`) derived from the inventory.
- **App CI deploys** with the collection's runner image (`ci/gitlab-deploy.yml`).

```bash
make setup && make vault-init && make vault-edit
make validate
make check LIMIT=edge-1
make apply LIMIT=edge-1 TAGS=nginx
make run PLAY=ops/restart LIMIT=relay-1 EXTRA="-e service=gost"
```

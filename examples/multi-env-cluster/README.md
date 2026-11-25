# Example: multi-environment k3s cluster + mail

A fuller example of the [IaC standard](../../docs/iac-standard.md):

- `inventories/{staging,prod}` with the **same groups**, different hosts and **separate vault
  ids** — every playbook runs unchanged against either environment (`ENV=staging`).
- One vaulted `vault_hosts` map per environment for addresses/ports instead of a vault file
  per host.
- **Attack-surface choices made explicit**: SSH and k8s API limited to an admin CIDR,
  exporters bound to the private interface and limited to the monitoring server, webmail on
  loopback behind nginx + WAF.
- A k3s cluster with embedded etcd (`cluster-init` / `join`), day-2 operations and a
  rolling upgrade as **ops playbooks**.
- A mail server (docker-mailserver) with ACME certificates.
- A **local role** (`roles/journald`) showing how to extend the collection.

```bash
make setup
make vault-init ENV=staging VAULT_PER_ENV=1 && make vault-edit ENV=staging
make vault-init ENV=prod VAULT_PER_ENV=1    && make vault-edit ENV=prod
make validate ENV=staging           # offline: vars vs. role argument specs
make check ENV=staging              # dry-run against staging
make apply ENV=staging LIMIT=k3s_cluster TAGS=core,node,k3s
make run PLAY=ops/k3s-day2 ENV=prod LIMIT=cp-1 EXTRA="-e action=fetch-kubeconfig"
```

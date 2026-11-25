# Debugging infrastructure

Investigation is **read-only**. The fix always lands in the repo
(see [operations.md](operations.md) — a debug session usually starts as kind 1 and ends as
kind 3).

---

## 1. Method

1. **Reproduce / observe**: what exactly fails, since when, for whom? Get the exact error.
2. **Narrow down**: which host, which layer (DNS → network → firewall → TLS → proxy →
   app → data)?
3. **Collect evidence** with read-only commands (below). Save the relevant output.
4. **Hypothesis**: one cause that explains *all* the evidence.
5. **Fix in code**, `make check` to see the diff, apply with a tight `LIMIT`.
6. **Verify** the original symptom is gone, and that `make check` shows no drift.
7. If the cause was a manual change (drift), say so and codify or revert it.

Avoid "fix by restart" without understanding: a restart is a valid mitigation (kind 2),
but write down the cause or open question.

## 2. Ansible-side diagnostics

| Need | Command |
|---|---|
| What vars does a host end up with? | `make host H=web-1` (vault values shown as `<hidden>`) |
| Where is a var defined? | `grep -rn 'core_ssh_port' inventories/ playbooks/` ; vault keys: `make vault-keys` (names only — values stay with the human, see security.md §5a) |
| Which group is a host in? | `make graph` |
| Value after templating | `make shell CMD='ansible web-1 -m ansible.builtin.debug -a var=nginx_sites'` (never for `vault_*`-derived values — security.md §5a) |
| Role default / meaning of a var | [roles-index.md](roles-index.md), `ansible-doc -t role ahmz1833.server_setup.<role>`, or `collections/ansible_collections/ahmz1833/server_setup/roles/<role>/defaults/main.yml` |
| Why did a task do X? | rerun the play with `-vvv` on `LIMIT=<host> TAGS=<tag>`; read the role's task file |
| Start mid-play | `EXTRA="--start-at-task 'Task name'"` or `--step` |
| Connection problems | `make shell -- ansible web-1 -m ansible.builtin.ping -vvvv`; check `ssh -G <alias>` |
| Check-mode differs from real run | some tasks depend on earlier changes; look for `when: not ansible_check_mode` and registered results |

Variable precedence surprises are the #1 cause of "my change does nothing": extra-vars
(`-e`) > task/include vars > play vars > host_vars > group_vars (child > parent > all) >
role defaults. Check that the var is not overridden at a higher level.

## 3. Host-side read-only diagnostics

Run them through the project toolchain (inventory, vault and collections preset):

```bash
make shell CMD='ansible web-1 -b -a "systemctl --failed"'   # one host, sudo
make shell CMD='ansible web -b -a "df -h"'                  # a whole group
make docker-logs H=web-1 C=app SINCE=30m                    # container logs
make shell                                                  # interactive, then plain ansible …
```

(`-a` without `-m` uses `ansible.builtin.command`; use `-m ansible.builtin.shell` only when you
need pipes.) Plain `ssh <host>` is fine for interactive digging.

| Area | Commands |
|---|---|
| Services | `systemctl status <svc>`, `systemctl --failed`, `journalctl -u <svc> -n 200 --no-pager`, `journalctl -p err -b` |
| Resources | `df -h`, `df -i`, `du -xh --max-depth=1 /var \| sort -h`, `free -h`, `uptime`, `top -bn1 \| head -30`, `dmesg -T \| tail` |
| Network | `ip -br a`, `ip r`, `ss -ltnup`, `ss -s`, `curl -sv http://127.0.0.1:<port>/`, `mtr -rwc 20 <dst>` |
| Firewall | `iptables -S HOST-FIREWALL`, `iptables -L INPUT -n -v --line-numbers`, `ipset list -n`, `nft list ruleset` (read only!) |
| DNS | `dig +short <name>`, `dig @1.1.1.1 <name>`, `resolvectl status`, `cat /etc/resolv.conf` |
| TLS | `openssl s_client -connect <host>:443 -servername <name> </dev/null \| openssl x509 -noout -dates -subject -ext subjectAltName` |
| Nginx | `nginx -t`, `nginx -T \| less`, `/var/log/nginx/*error.log`, ModSecurity audit log |
| Docker | `docker ps -a`, `docker logs --tail 200 <c>`, `docker inspect <c>`, `docker stats --no-stream`, `docker system df` |
| k3s | `kubectl get nodes -o wide`, `kubectl get pods -A -o wide \| grep -v Running`, `kubectl describe pod <p> -n <ns>`, `kubectl logs <p> -n <ns> --previous`, `kubectl get events -A --sort-by=.lastTimestamp \| tail -30`, `journalctl -u k3s -n 200` |
| Mail | `docker logs mailserver`, `setup email list` inside the container, `dig MX/TXT <domain>` |
| Certificates on disk | `openssl x509 -in /etc/ssl/certs/<cn>/fullchain.pem -noout -dates -ext subjectAltName` |

Commands that **change state** (`systemctl restart`, `iptables -A`, `kubectl delete`,
`docker rm`, editing files) are not diagnostics. Do them only as a deliberate kind-2
operation or break-glass, and record them.

## 4. Common failure patterns

| Symptom | Usual suspects |
|---|---|
| Connection refused from outside, works on host | host firewall (`HOST-FIREWALL` chain), service bound to `127.0.0.1`, provider security group |
| Timeout from outside | provider firewall, wrong IP/DNS, routing, upstream blocking (common for Iranian hosts: try via `is_iran` mirrors/proxy settings) |
| 502/504 from nginx | upstream container down/unhealthy, wrong upstream port, Docker network, slow app (timeouts) |
| 403 from nginx | WAF (ModSecurity) rule — check the audit log for the rule id, then whitelist it in `waf_extra_rules` for that site |
| TLS errors | cert expired / wrong SAN / not deployed to the path nginx uses (`nginx_ssl_cert_dir/<domain>/`) |
| Package/download failures | mirror unreachable; `is_iran`/`download_locally` settings; proxy (`node_singbox_*`) |
| Firewall rules vanish after Docker/k3s restart | something flushed INPUT; the collection's `host-firewall-enforce` service re-inserts `HOST-FIREWALL` — check it is running |
| Ansible "changed" every run | non-idempotent task (shell without `changed_when`, templated timestamps) |
| Var change has no effect | precedence override, wrong group, typo in var name (argument_specs warn only for known options) |

## 5. Reporting

Whether a human writes the incident note or an agent replies, include: symptom, root
cause, evidence (trimmed command output — **without** IPs/ports/secrets if it is going into
the repo or a public tracker), fix (commit), verification, and follow-ups.

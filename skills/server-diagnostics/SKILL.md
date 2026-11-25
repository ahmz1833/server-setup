---
name: server-diagnostics
description: Debug availability and performance of servers and the services on them, and measure/vet machines - outages, downtime, flapping, restarts, slowness, saturation, resource exhaustion, packet loss, throughput; using every metrics/logging source available (Prometheus-style metrics, exporters, logs, Kubernetes metrics, sysstat, provider graphs); plus benchmarks (CPU/memory/disk), network tests between servers or to the internet (iperf3, mtr) and egress/IP reputation checks. Use for any "why is X down/slow/unstable", "is this server good enough", "test bandwidth", "is this IP clean" request, whatever the workload (Kubernetes, VPN/tunnels, web, databases, mail, CI...). Read-only and ephemeral by default; fixes go through infra-iac.
---

# Server diagnostics: availability, performance, measurement

Applies to any workload. Examples below are illustrations, not a checklist — work out what
matters for the system in front of you.

These are **inspect / one-off** jobs in `infra-iac`'s task intake: they leave every server
exactly as found. When the outcome needs a lasting change (tuning, capacity, config,
firewall, monitoring), hand over to `infra-iac`'s change loop.

## Principles

1. **Read-only first, evidence over guesses.** Observe, then hypothesize; one cause must
   explain all evidence. Restarting to "fix" is a mitigation (ask first), not a diagnosis.
2. **Use history, not just "now".** Most availability and performance problems are about
   *when* and *what changed*. Find and use every metrics/log source that exists (Step 2)
   before running live probes.
3. **Ephemeral, leave no trace.** Anything you install, start, open or write for a test is
   removed afterwards — packages you added, listeners, temporary firewall rules, test files.
   Verify cleanup and report it.
4. **Confirm before load.** Benchmarks and throughput tests saturate CPU/disk/links. On
   production say what, how long, expected impact, and get an OK. Prefer short runs.
5. **Discover tools, don't assume them.** Tools and helper scripts change. Check what exists
   on the host and read its `--help` before each use; build commands from what it says
   today. Fall back to standard tools when something is missing or behaves differently.
6. **Minimal exposure.** Address hosts by inventory name; reference addresses inside
   commands via inventory variables (`{{ hostvars['<host>'].ansible_host }}`); never ask for
   or print real IPs, ports or secrets; mask IPs in output before reading it (filter below);
   don't paste raw outputs into the repo.
7. **Run on servers through the project Makefile** (connection resolved from inventory and
   vault): `make shell H=<host|group> -- <cmd>` (or `CMD='…'` with quotes/`=`; sudo by default,
   `SUDO=0` for the login user; a `.become_pass` file is used automatically if sudo needs a
   password), `make module H=… M=<module> A='<args>'` for any module
   (`EXTRA='-B 300 -P 0'` for background jobs), `make docker-logs`, `make var`. No project: an
   inventory the user prepares, or their `~/.ssh/config` aliases.

```bash
# IP mask — pipe any output through this before reading it
sed -E 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<ipv4>/g; s/\b([0-9a-fA-F]{0,4}:){3,7}[0-9a-fA-F]{1,4}\b/<ipv6>/g'
```

## Step 1 — Frame the problem

- Symptom in the user's terms → measurable: what fails/slows, for whom, how often, since when.
- Scope: one host / group / service / region / all? Inside vs outside the network?
- What changed: IaC history (`git log --since`), recent applies, image/version bumps, provider
  maintenance, traffic changes, certificate expiry, `make check` drift (manual changes).
- Severity: ongoing outage → stabilize first (with the user's OK), investigate in parallel.

## Step 2 — Discover observability (always, before live probing)

Find out what exists — probe, don't assume. Typical places (illustrative):

| Source | How to find it | Gives |
|---|---|---|
| Metrics servers (Prometheus, VictoriaMetrics, Thanos, Mimir…) | inventory/`apps_list`/k8s manifests, `ss -ltnp` on the monitoring host, `docker ps` | history: query `…/api/v1/query_range` from that host (`curl localhost:<port>`), `ALERTS` for firing alerts |
| Exporters on targets (node, nginx, docker daemon, cAdvisor, blackbox, app `/metrics`) | collection vars (`node_exporter_*`, `nginx_exporter_*`, `node_docker_metrics_*`), `ss -ltnp` | current values directly; history via the metrics server |
| Dashboards / alerting (Grafana, Alertmanager, uptime checkers) | inventory, apps, DNS names in the repo | what alerted and when; ask the user for screenshots if you can't reach it |
| Logs (journald, Loki/Promtail, nginx/WAF logs, container logs, k8s events) | `journalctl --list-boots`, `nginx_promtail_*`, `make docker-logs` | error timelines, restarts, OOM kills |
| Kubernetes | `kubectl top`, metrics-server, kube-state-metrics, `get events`, Prometheus operator | pod/node usage, restarts, evictions, scheduling |
| Host history (sysstat `sar`, `atop` logs, `last -x`, `/var/log`) | presence check on host | CPU/IO/net history without a metrics stack |
| Provider console | ask the user | host-level CPU/net graphs, maintenance events, DDoS mitigation |

If little exists, say so and suggest (as an IaC change) the minimal observability that
would have answered the question — e.g. enabling exporters already in the collection.

## Step 3 — Analyze

- **Resources (USE)**: for CPU, memory, disk, network, file descriptors, conntrack,
  ephemeral ports: utilization, saturation (queues, steal, swap, iowait, drops), errors.
- **Services (RED)**: request rate, errors, duration — at the edge (nginx/ingress) and per
  backend.
- **Layers** for reachability: DNS → routing/path → provider filter → host firewall →
  listener → TLS → proxy → app → dependency/data.
- **Availability specifics**: did the *host* go away (reboot/panic: boots list, `dmesg`,
  provider events), the *service* (systemd `NRestarts`, container restart counts, k8s
  CrashLoop/OOMKilled/evictions), the *network* (loss, routing, upstream blocks), or a
  *resource* run out (disk/inodes full, memory/OOM, conntrack/fd limits, cert expiry)?
  Flapping → correlate with timers/cron, backups, traffic peaks, autoscaling, health-check
  thresholds.
- **Workload signals**: identify the workload's own health indicators and check them, e.g.
  cluster node/pod conditions and etcd latency; VPN/tunnel handshakes, session counts,
  per-tunnel throughput, MTU/fragmentation, crypto CPU; web latency and error rates; DB slow
  queries and locks; mail queues and deferrals; CI runner queue times.

Command cookbook and common failure patterns: `references/debugging.md`.

## Step 4 — Active measurement (when history isn't enough, or to vet a machine)

### Tools on the host first

Servers configured by the collection's **node** role usually already have helper scripts:
its bootstrap installs the user's dotfiles scripts into the admin user's `~/.local/bin`
(run as that user, or by full path). Check presence before anything else:

```bash
make shell H=<host> SUDO=0 CMD='ls ~/.local/bin; command -v sysbench fio iperf3 mtr'
```

Helpers you may find there (names and options may change — read `--help`):

- **linux-bench** — sysbench-based CPU/memory/threads/mutex/disk benchmark with comparable
  scores; has dependency and info modes.
- **egress-check** — egress and IP-reputation vetting: geo consistency across databases,
  blacklists/fraud scores, proxy/VPN flags, service geo-blocks, mail egress (port 25, PTR,
  SPF/DMARC with a domain), dual-stack; JSON output available.

Fallback order when a tool is missing: install the standard package temporarily → fetch the
helper on the controller (`https://raw.githubusercontent.com/ahmz1833/dots/main/scripts/<name>`)
and run it with `make module H=<host> SUDO=0 M=ansible.builtin.script A='<local path> <args>'`
(copies, runs, deletes; works for hosts without GitHub access) → standard tools (`sysbench`, `fio`, `iperf3`, `mtr`, `curl -w`, `dd oflag=direct`).

### Benchmarks

Check dependencies (install temporarily if needed), run short tests in a disk location with
enough space, clean up. Compare only like with like (same tool version and options). Look for
poor multi-thread scaling and high steal (oversubscribed host), direct vs buffered disk gaps,
run-to-run noise (repeat when unsure).

### Network between servers — iperf3, strictly ephemeral

The iperf3 server exists only for the test window:

1. iperf3 on both hosts (temporary install if missing; any packaged daemon stays disabled).
2. Temporary firewall allow on the server for an unused high port, **from the client's
   address only**, at the top of the active chain (collection firewall: `HOST-FIREWALL`;
   otherwise the nft/ufw setup you find). Account for NAT and provider security groups.
3. Start the server time-bounded in the background, e.g.
   `make module H=<srv> M=ansible.builtin.command A='timeout 240 iperf3 -s -p <port>' EXTRA='-B 300 -P 0'`
   (or one-shot mode if available).
4. From the client: both directions (normal and `-R`), ~10 s each; optionally parallel
   streams (`-P N`) to separate per-flow from link limits; target the server via
   `{{ hostvars['<srv>'].ansible_host }}` or its private address. For tunnels/VPNs, test both
   the underlay (host to host) and through the tunnel to see the overhead.
5. Cleanup **always**, even after failures: stop the server, delete the firewall rule,
   remove temporary packages; verify nothing listens and the rule is gone.

### Network to the internet

`iperf3 -c iperf3.moji.fr -p 5210` (and `-R`) is a good international default; public
servers get busy — retry later or use another. Add `mtr` towards the regions that matter and
an HTTP download test where iperf3 is blocked.

### IP reputation / egress

Run the egress checker on the host itself (it evaluates the host's own egress), with the
mail-domain option for mail senders. Use its own verdicts; mask IPs before reading. Explain
consequences: geo mismatches (services may geo-block), blacklist/fraud hits (change IP or
provider), port 25 blocked or missing PTR (mail not viable until fixed with the provider),
blocked AI/streaming/social services (other region or egress route).

## Reporting

- Findings: symptom → root cause (or ranked hypotheses with the evidence for each) →
  timeline.
- Measurements: table per host (names only), tool + version/commit + options + duration, key
  numbers, comparison.
- Cleanup confirmed (packages, listeners, rules, files).
- Recommendations: immediate mitigation vs durable fix; durable fixes and missing
  observability go through `infra-iac` (IaC change loop).

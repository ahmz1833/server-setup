# Changelog

All notable changes to this project will be documented in this file.

## [1.6.2] - 2026-11-26

### Fixed
- **core**: read-only safety checks (SSH keys/non-root user, swap, cron listing, IPv6 lookup)
  run in check mode, so `--check` no longer fails on them.
- **core**: installs cron when it manages cron jobs (minimal images lack `crontab`).

### Changed
- **asset**: hosts with `is_iran` fetch release assets from the S3 mirror by default
  (`asset_use_mirror` derived from `is_iran`, `asset_mirror_base_url` set to the mirror).

## [1.6.1] - 2026-11-25

### Fixed
- **mail**: the SnappyMail admin password is passed to `php` through an environment variable
  instead of being spliced into the command line (it was visible in logs/process list and
  broke on quotes); password, hash and secret admin path tasks are `no_log`.
- **mail**: printed DNS instructions use `mail_hostname` (were hard-coded to
  `mail.<mail_domain>`); role meta declares `community.general` (used by `ini_file`).
- **apps**: prune always protects containers labelled `apps.ansible.prune.whitelist=true`
  (set by the mail role), even when `apps_prune.whitelist_labels` is customised — mail
  containers could be removed by `apps_prune`.
- **apps**: defaults comment documented `capabilities: {add, drop}`, which fails; corrected
  to `capabilities: [...]` (add) and `cap_drop: [...]`. Prune comments corrected (master
  switch default, built-in name patterns).
- **core**: `core_users[].group` is now the user's primary group (it was only created, never
  assigned); `core_apt_update_retries` / `core_apt_update_retry_delay` declared in defaults.

### Changed
- **mail** README documents paths, network, webmail port and the prune-protection label.

## [1.6.0] - 2026-11-25

### Added
- **skills**: `server-diagnostics` — availability and performance debugging for any workload
  (discovers and uses available metrics/log sources first: Prometheus-style metrics,
  exporters, logs, Kubernetes metrics, sysstat, provider graphs), USE/RED analysis,
  benchmarks and egress/IP-reputation checks with the helper scripts the node role's
  bootstrap installs, strictly ephemeral iperf3 tests between servers and to public servers.
  Leaves no trace, masks IPs, hands durable fixes to `infra-iac`.

### Changed
- **infra-iac** routes debugging/performance/measurement requests to `server-diagnostics`.
- **examples Makefile**: `make shell` now works on the **servers** — `make shell H=<host>`
  opens an SSH session (connection resolved from inventory + vault), `make shell H=<pattern>
  -- <cmd>` / `CMD='…'` runs a command on one or many hosts (sudo; `SUDO=0`). New
  `make module` (any Ansible module) and `make var` (templated variable, vault values
  refused). The local toolchain subshell from 1.5.x is removed.
- **examples Makefile**: a sudo password file (`.become_pass[.<env>]` or `.become-pass[.<env>]`,
  gitignored) is passed with `--become-password-file` to every ansible command — no prompt;
  `BECOME_ASK=1` still prompts when there is no file.

### Fixed
- **galaxy.yml**: `dist/` excluded from the collection build (an empty `dist/` was shipped in 1.5.1).

## [1.5.1] - 2026-11-25

### Fixed
- **galaxy.yml**: at most 20 tags (Galaxy rejected the 1.5.0 import with 21 tags, so 1.5.0
  was never published to Galaxy; the 1.5.0 runner image on GHCR has the same content).
- **CI**: checks the Galaxy tag limit so metadata errors fail before release.

## [1.5.0] - 2026-11-25

### Added
- **all roles**: `meta/argument_specs.yml` — every user-settable variable is validated at
  runtime and documented via `ansible-doc -t role ahmz1833.server_setup.<role>` (core also
  has a `firewall` entry point). Specs are permissive (`raw` for templated values).
- **docs/**: IaC project standard (`iac-standard.md`, incl. collection-first rule and other
  IaC tools), security guide with two threat models — public repository and runtime attack
  surface (`security.md`), operations (task-intake model, change loop, drift, day-2),
  debugging cookbook, toolchain, generated `roles-index.md`.
- **examples/**: complete projects — `starter` (single server), `multi-env-cluster`
  (staging/prod, per-env vault ids, k3s HA, mail, local role), `fleet` (heterogeneous
  servers, function + location groups, CI app deploys). Standard Makefile with `setup`,
  `shell` (`make shell -- <cmd>`), `validate` (offline argument-spec check), `check`,
  `apply`, `run`, `vault-*`, `lint`, `docker-shell`.
- **skills/**: AI agent skills `infra-iac`, `infra-bootstrap`, `server-setup-dev`;
  installable as a Claude Code plugin (`.claude-plugin/`) or with `npx skills add
  ahmz1833/server-setup`, and shipped inside the collection tarball.
- **scripts/**: `ensure-toolchain.sh` (installs ansible if needed and the latest collection
  into the project), `gen-roles-index.py`, `sync.sh` (single-source copies),
  `check-consistency.py` (defaults ⇄ argument specs), `test-examples.sh`.
- Root `requirements.yml`, `CLAUDE.md`, `.dockerignore`.

### Changed
- **Dockerfile**: pinned base image; installs the collection from the build context (image
  tag = collection version); includes `make`, `bash`, passlib, jmespath and all dependencies.
- **CI**: consistency, sync drift, skills/manifest checks, `ansible-doc` for all roles,
  example projects (vault, syntax, argument specs, lint), runner image smoke test. Release
  checks the plugin version.
- **AGENTS.md**: source-of-truth map and a mandatory doc-impact checklist for role changes.
- `min_ansible_version` 2.15 in all roles (matches `meta/runtime.yml`).
- **README**: AI agents, starting a project, examples, accurate role/asset descriptions and
  repository layout.

### Fixed
- **acme** README: Cloudflare DNS-01 automation documented (was described as unsupported);
  `acme_cloudflare_zone`, per-cert `dns_provider`/`zone` added.
- **k3s** README: removed non-existent `k3s-*` tags; corrected task order.
- **mail** README: example no longer uses a real domain or plaintext passwords.
- **node** `examples/docker.yml`: Docker `{{.Name}}` log tag marked `!unsafe` (broke templating).

## [1.4.18] - 2026-10-12

### Added
- **node**: `node_exporter_textfile_scripts` run scripts on timers for the textfile collector.

### Fixed
- **core**: `core_firewall_pre_chains` stay ahead of HOST-FIREWALL in INPUT.

## [1.4.17] - 2026-10-09

### Fixed
- **acme**: Cloudflare zone is derived per record, so multi-zone certs validate.

## [1.4.16] - 2026-10-09

### Fixed
- **acme**: renew when the cert's domains change, not only on expiry.

## [1.4.15] - 2026-10-09

### Added
- **node**: `node_gost_ingress_allow` rules accept `connlimit` / `rate` (per-source, kernel); `src` optional.

## [1.4.14] - 2026-10-02

### Fixed
- **node**: x-ui cert paths were never parsed (over-escaped regex in a folded scalar), so certs were re-applied and x-ui restarted every run.

## [1.4.13] - 2026-10-02

### Added
- **acme**: Cloudflare DNS-01 automation (`acme_dns_provider: cloudflare`).
- **node**: `node_xui_settings` writes panel DB settings without CLI flags (e.g. `subEnable`, `subPort`).

### Fixed
- **node**: x-ui 3.6+ hides username and cert paths in `setting -show`; the role re-applied credentials and certs (restarting x-ui) every run. Cert paths now come from `setting -getCert`, credentials are tracked by a hash marker (`node_xui_cred_marker`).
- **node**: Panel cert paths are applied only once the files exist.

### Changed
- **node**: Default versions: sing-box 1.14.2, x-ui 3.8.5, gost 3.3.0, docker 29.8.2, buildx 0.37.2, compose 5.6.0, node_exporter 1.12.1, gitlab-runner 19.4.1, dust 1.2.6, fzf 0.74.4, eza 0.23.5, yazi 26.9.1, zoxide 0.10.0, starship 1.26.0, wgcf 2.3.0. sing-box 1.14 warns on `independent_cache` / `store_rdrc` (removed in 1.16).

## [1.4.12] - 2026-10-02

### Added
- **core**: `core_ipv6_interfaces` — IPv6 per interface (auto RA/DHCPv6 or static) via networkd drop-in.
- **node**: `node_gost_egress_guard`, `node_gost_ingress_allow` — iptables guards for gost.

## [1.4.11] - 2026-10-02

### Added
- **node**: gost self-signed TLS (`node_gost_tls_selfsigned`) and cert pinning (`node_gost_tls_trust_hosts`).
- **node**: `node_gost_limit_nofile`, `node_gost_environment`.

### Fixed
- **core**: Disabling `ssh.socket` no longer locks SSH out on Ubuntu 24.04 (leftover listener kept port 22, `/run/sshd` removed).

## [1.4.10] - 2026-09-28

### Added
- **k3s**: `k3s_traefik_config.ports.<web|websecure>.transport` is passed to Traefik (e.g. `respondingTimeouts.readTimeout`).

## [1.4.9] - 2026-09-25

### Fixed
- **core**: The Debian/Ubuntu package-cache task no longer trusts `cache_valid_time` right after the role rewrites APT mirrors — the stale index from the previous mirror survived and package lookups failed with "No package matching 'htop' is available". The refresh is now forced whenever the mirror swap changed anything, and the update retries 3 times (5 s delay) against flaky mirrors.
- **core**: The default Iranian mirrors moved to the Nexus CDN `https://mirror.cdn.ir/repository/{debian,ubuntu}` (note the `/repository/` prefix; trixie + noble Release verified 200) — Debian was previously `mirrors.pardisco.co` (connection timeouts), Ubuntu `ir.ubuntu.sindad.cloud`. Override with `core_base_mirror_debian` / `core_base_mirror_ubuntu` per site if needed.

## [1.4.8] - 2026-08-26

### Fixed
- **sudo-rs Compatibility (Ubuntu 25.10+/26.04)**: The per-user sudoers file written by the `core` role (`/etc/sudoers.d/<user>`) now ends with a newline. Ubuntu 26.04 LTS ships sudo-rs as the default sudo implementation, and its stricter `visudo -cf %s` validation rejects files without a trailing line terminator ("missing line terminator at end of file"), which made user provisioning fail on 26.04 hosts while older releases passed. Classic GNU sudo accepts both forms, so existing hosts are unaffected.

### Changed
- **Platform Metadata**: All roles' `meta/main.yml` now declare Ubuntu `plucky` (25.04), `questing` (25.10), and `resolute` (26.04 LTS) alongside focal/jammy/noble, matching actual support.

## [1.4.7] - 2026-08-26

### Added
- **K3s kubelet-arg Assembly**: Role-contributed kubelet flags (node-local DNS `cluster-dns`) are emitted together with user-supplied flags (`k3s_kubelet_args`) instead of whichever copy won the duplicate YAML key.
- **K3s CPU Manager Support**: New `k3s_cpu_manager_policy`, `k3s_kube_reserved`, and `k3s_system_reserved` variables; stale `/var/lib/kubelet/cpu_manager_state` is discarded automatically when the policy changes (kubelet refuses to start otherwise).
- **Traefik Service External Traffic Policy**: Configurable `service.externalTrafficPolicy` rendered into the Traefik `HelmChartConfig`.
- **Traefik DaemonSet Enforcement for Local Traffic Policy**: `service.externalTrafficPolicy: 'Local'` automatically pins Traefik to `deployment.kind: DaemonSet` (with Local, only nodes running a Traefik pod answer traffic); an explicit contradictory deployment kind fails validation.
- **Traefik Forwarded Header Trust Controls**: New `forwardedHeaders.trustedIPs` / `.insecure` settings (global, with per-entrypoint overrides via `ports.web/websecure.forwardedHeaders`) governing acceptance of `X-Forwarded-For` / `X-Real-Ip`, enabling trusted-proxy and CDN whitelisting; IP/CIDR entries are format-validated during provisioning.
- **Kubelet Arg Variable Isolation**: Kubelet flags are configured exclusively through `k3s_kubelet_args`; setting `kubelet-arg` inside `k3s_config` fails validation instead of being merged or silently dropped.

### Fixed
- **Traefik HelmChartConfig Rendering**: Fixed Jinja2 whitespace stripping that moved the `ports:` block out of `spec.valuesContent` onto the manifest root, silently discarding all port customization.

## [1.4.6] - 2026-08-26

### Added
- **Mail Sync Change Report**: The mail user-sync run now reports which accounts were added, updated, deleted, or kept.
- **Mail Role Prerequisites Documentation**: Documented hard requirements in `roles/mail/README.md` — manual TLS certificates must exist before the run (`SSL_TYPE=manual`, read-only bind mount), ports 25/465/587/993 must be opened outside the role, required DNS records (A, MX, SPF, DMARC, DKIM), and provider PTR/rDNS expectations.
- **Mail SMTP Client Usage Guide**: Documented how other systems send mail through the server using the `noreply` credential (submission 587 + STARTTLS) and how `SPOOF_PROTECTION` restricts sender identity, with the admin account as the only spoof-capable exception.

### Changed
- **Mail User Sync Hardening**: The sync script is now written root-owned with `0700` permissions, executed via explicit `/bin/bash`, and removed after every run — successful or failed — so credentials never linger on disk; script write/execute tasks are suppressed from Ansible logs (`no_log`).

## [1.4.5] - 2026-08-21

### Changed
- **K3s Image Pull Proxy Documentation**: Documented how to set/unset image-pull proxy environment (`HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY`) through the existing `k3s_env` variable in `roles/k3s`, including cluster-internal `NO_PROXY` exclusions.

## [1.4.4] - 2026-08-21

### Fixed
- **Sing-box DNS Routing**: Added configurable final DNS server routing, defaulting to the remote resolver while allowing direct resolution when remote DNS resolution is unavailable.
- **Sing-box IPv6 Queries**: Return `NOERROR` for blocked AAAA queries so IPv4-only configurations handle IPv6 lookups without treating them as resolver failures.

## [1.4.3] - 2026-08-21

### Added
- **Sing-box TUN Route Exclusions**: Added `node_singbox_tun_route_exclude_address` to `roles/node` defaults and template to route private/LAN CIDRs (RFC1918, link-local, CGNAT) and K3s cluster/pod/service networks direct on the host, preventing tunnel hijacking of local and cluster traffic.

## [1.4.2] - 2026-08-21

### Fixed
- **K3s NodeLocalDNSCache TTL Tuning**: Reduced cluster domain DNS cache TTL (success from 30s to 5s, denial from 5s to 1s) in `node-local-dns.yaml.j2` to accelerate service discovery and pod endpoint updates across dynamic cluster workloads.

## [1.4.1] - 2026-08-20

### Added
- **K3s NodeLocalDNSCache Support**: Implemented NodeLocalDNSCache DaemonSet deployment, Corefile template, live kube-dns ClusterIP discovery, and kubelet `cluster-dns` configuration (`k3s_node_local_dns`) for low-latency node-local DNS caching and upstream fallback.

## [1.4.0] - 2026-08-16

### Added
- **`ahmz1833.server_setup.k3s` Role**: Production-ready, property-driven K3s cluster provisioning, scale-out, and Day 0 / Day 1 / Day 2 operational management across any topology (Multi-Master HA etcd, standalone, and dedicated worker agents).
- **DNS-Based Control Plane Load Balancing**: Declarative `k3s_control_plane_domain` and `k3s_control_plane_port` variables with automatic TLS SAN embedding and seamless integration with external load balancers or round-robin DNS.
- **Bootstrapping `/etc/hosts` Support**: Automatic temporary control plane hostname resolution in `/etc/hosts` during cluster setup, cleanly removed in an `always:` post-provisioning block.
- **Customizable Ingress & ServiceLB Integration**: Configurable Traefik `HelmChartConfig` port definitions supporting `LoadBalancer`, `ClusterIP`, and `NodePort` modes with explicit `hostPort` / `nodePort` assignments.
- **Full Day 2 Operational Lifecycle**: Automated node draining/uncordoning (`k3s_state: drain`/`uncordon`), TLS certificate rotation (`rotate-certs`), local kubeconfig retrieval (`fetch-kubeconfig`), and safe node decommissioning (`absent` / `uninstall`).

## [1.3.8] - 2026-08-16

### Added
- **Dedicated `HOST-FIREWALL` Custom Chain**: Refactored `roles/core` firewall tasks to isolate host security rules into a custom `HOST-FIREWALL` chain at index 1 of `INPUT`, preserving `:INPUT ACCEPT` for K8s CNI and pod traffic.
- **Continuous Enforcement Daemon**: Deployed background daemon `host-firewall-enforce.service` (`/usr/local/bin/host-firewall-enforce.sh`) to continuously maintain `HOST-FIREWALL` at index 1 of `INPUT` across reboot and K3s/Kube-Router service restarts (`core_firewall_enforce_interval: 300`).
- **Selective Rule Persistence**: Overwriting `/etc/iptables/rules.v4` to store **ONLY** `HOST-FIREWALL` definitions, preventing dynamic/ephemeral K8s pod/service chains (`KUBE-*`, `CNI-*`, `FLANNEL-*`, `DOCKER-*`) from persisting to disk.
- **DRY Save Tasks**: Refactored Debian and RedHat iptables save tasks into a single looped task.

### Fixed
- **Asset Installer Version Matching**: Fixed string vs int comparison in `roles/asset` by stripping leading `v` prefixes prior to semver comparison.
- **Mail Role Galaxy Tag**: Replaced hyphenated `docker-mailserver` tag with valid `mailserver` tag in `roles/mail/meta/main.yml`.

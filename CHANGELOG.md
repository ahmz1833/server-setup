# Changelog

All notable changes to this project will be documented in this file.

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

# Changelog

All notable changes to this project will be documented in this file.

## [1.3.8] - 2026-08-16

### Added
- **Dedicated `HOST-FIREWALL` Custom Chain**: Refactored `roles/core` firewall tasks to isolate host security rules into a custom `HOST-FIREWALL` chain at index 1 of `INPUT`, preserving `:INPUT ACCEPT` for K8s CNI and pod traffic.
- **Continuous Enforcement Daemon**: Deployed background daemon `host-firewall-enforce.service` (`/usr/local/bin/host-firewall-enforce.sh`) to continuously maintain `HOST-FIREWALL` at index 1 of `INPUT` across reboot and K3s/Kube-Router service restarts (`core_firewall_enforce_interval: 300`).
- **Selective Rule Persistence**: Overwriting `/etc/iptables/rules.v4` to store **ONLY** `HOST-FIREWALL` definitions, preventing dynamic/ephemeral K8s pod/service chains (`KUBE-*`, `CNI-*`, `FLANNEL-*`, `DOCKER-*`) from persisting to disk.
- **DRY Save Tasks**: Refactored Debian and RedHat iptables save tasks into a single looped task.

### Fixed
- **Asset Installer Version Matching**: Fixed string vs int comparison in `roles/asset` by stripping leading `v` prefixes prior to semver comparison.
- **Mail Role Galaxy Tag**: Replaced hyphenated `docker-mailserver` tag with valid `mailserver` tag in `roles/mail/meta/main.yml`.

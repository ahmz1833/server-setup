# Ansible Role: ahmz.server_setup.core

Core system provisioning, security hardening, and baseline configuration for Linux servers.

## Description

This role establishes the foundational layer of a server. It ensures the system is secure, up-to-date, configured with standard administrative tools, and protected by strict firewall rules.

## Available Tags

Use these tags to selectively run parts of the core setup:

* `core`: Runs the entire role.
* `core-system`: Hostname, timezone, APT mirrors, and base packages.
* `core-ntp`: Time synchronization configuration.
* `core-swap`: Swap file management.
* `core-users`: User creation, SSH keys, and sudoers.
* `core-ssh`: SSH daemon hardening.
* `core-sysctl`: Kernel tuning.
* `core-ipset`: IPSet creation and auto-updaters.
* `core-firewall`: IPv4/IPv6 INPUT chain configuration.
* `core-fail2ban`: Intrusion prevention system.
* `core-cron`: Centralized cron management.

## Role Variables

Most configurations are defined in `defaults/main.yml`.

### Global Toggles
| Variable | Description | Default |
|---|---|---|
| `core_is_iran` | Adjusts timezone and APT mirrors automatically. | `false` |
| `core_enable_ipv6` | Enables IPv6 sysctl and firewall rules. | `false` |
| `core_primary_user` | Primary administrative user (not removed). | `"root"` |

### Component Toggles
| Variable | Default | Variable | Default |
|---|---|---|---|
| `core_manage_ntp` | `true` | `core_manage_sysctl` | `true` |
| `core_manage_swap` | `true` | `core_manage_ipset` | `true` |
| `core_manage_users` | `true` | `core_manage_firewall` | `true` |
| `core_manage_ssh` | `true` | `core_fail2ban_enabled`| `true` |
| `core_manage_cron` | `true` | | |

## Example Playbook

```yaml
- name: Provision Base Server
  hosts: all
  vars:
    is_iran: true
    enable_ipv6: false
    
    # User Management
    core_users:
      - name: admin
        groups: ["sudo", "docker"]
        shell: /bin/bash
        ssh_keys:
          - "~/.ssh/id_rsa.pub"
        sudoer: true
        sudoer_no_pass: true

    # Firewall Configuration
    core_firewall_default_policy: "DROP"
    core_firewall_rules:
      - { port: 80, comment: "HTTP" }
      - { port: 443, comment: "HTTPS" }
      - { port: 8443, ipset: "trusted-ips", comment: "Metrics" }

    # IPSet Configuration
    core_ipsets:
      - name: trusted-ips
        type: hash:net
        entries:
          - "10.0.0.0/8"

  roles:
    - ahmz.server_setup.core
```

## License
MIT

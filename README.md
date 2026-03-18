# Ansible Collection: ahmz.server_setup

Ansible collection for provisioning and hardening Linux servers. Includes roles for core system setup, networking/tunnel services, Nginx with WAF, ACME/SSL certificate management, and Docker-based application deployment.

## Requirements

- Ansible >= 2.14
- Python >= 3.9

### Collection Dependencies

Installed automatically when using `ansible-galaxy`:

- `community.general` >= 5.0.0
- `community.crypto` >= 2.0.0
- `community.docker` >= 3.0.0
- `ansible.posix` >= 1.4.0
- `ansible.utils` >= 2.0.0

## Installation

### From Galaxy (when published)

```bash
ansible-galaxy collection install ahmz.server_setup
```

### From Git Repository

Add to your project's `requirements.yml`:

```yaml
collections:
  - name: https://github.com/ahmz1833/server-setup.git
    type: git
    version: master
```

Then install:

```bash
ansible-galaxy collection install -r requirements.yml
```

### Build and Install Locally

```bash
cd /path/to/this/repo
ansible-galaxy collection build
ansible-galaxy collection install ahmz-server_setup-*.tar.gz
```

## Roles

### `ahmz.server_setup.core`

Core server hardening: timezone, hostname, APT mirrors (with Iran/Arvan mirror support), package installation, user management, SSH hardening, iptables firewall, sysctl tuning, and fail2ban.

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz.server_setup.core
      vars:
        is_iran: false
        core_manage_users: true
        core_manage_ssh: true
        core_manage_firewall: true
```

### `ahmz.server_setup.node`

Node-level services: sing-box proxy/tunnel, GOST tunnel, Docker engine, Prometheus node_exporter, shell bootstrap and utility tools.

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz.server_setup.node
      vars:
        node_docker_enabled: true
        node_gost_enabled: true
        node_exporter_enabled: true
```

### `ahmz.server_setup.nginx`

Full Nginx setup: installation, ModSecurity WAF, global tuning, SSL/TLS, per-site vhost generation, custom error pages, nginx-prometheus-exporter, and Promtail log shipping.

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz.server_setup.nginx
      vars:
        nginx_managed: true
        nginx_sites:
          - domain: "example.com"
            ssl_enabled: true
            upstream: "http://127.0.0.1:8080"
```

### `ahmz.server_setup.acme`

ACME/Let's Encrypt certificate issuance and renewal via DNS-01 or HTTP-01 challenges.

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz.server_setup.acme
      vars:
        acme_account_email: "admin@example.com"
        acme_certificates:
          - domains:
              - "example.com"
              - "*.example.com"
```

### `ahmz.server_setup.apps`

Docker container lifecycle manager: creates directories, ensures networks, reconciles container state, and prunes unmanaged containers.

```yaml
- hosts: all
  become: true
  roles:
    - role: ahmz.server_setup.apps
      vars:
        apps_to_deploy:
          - name: myapp
            image: myapp:latest
            ports:
              - "8080:80"
```

## Global Variables

These variables are referenced across multiple roles and should be set at the inventory or playbook level:

| Variable | Default | Description |
|---|---|---|
| `is_iran` | `false` | Enables Iran-specific mirrors and download proxying |
| `enable_ipv6` | `false` | Enables IPv6 support across all roles |
| `primary_user` | `root` | Primary admin user for the server |
| `download_locally` | `false` | Download binaries on controller first, then copy to target |

## License

MIT

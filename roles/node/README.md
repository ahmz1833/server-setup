# Ansible Role: ahmz.server_setup.node

Middle-layer services deployment including networking tunnels, monitoring, Docker runtime, and administrative shells.

## Description

The `node` role handles the installation and configuration of services running directly on the host. It utilizes the `ahmz.server_setup.asset` role to idempotently download and deploy required binaries.

## Requirements
* **Dependency**: `ahmz.server_setup.asset`
* **Local Requirement**: If utilizing `sing-box` outbound links, `vpnparser` must be installed on the Ansible control node:
  `go install github.com/ahmz1833/vpnparser@latest`

## Available Tags

* `node`: Runs the entire role.
* `node-singbox`: Deploy and configure sing-box.
* `node-tools`: Install packages (btop, jq, etc.) and run shell bootstrap.
* `node-bootstrap`: Specific to the ZSH/dotfiles bootstrap script.
* `node-gost`: Deploy GOST tunnel.
* `node-xui`: Deploy 3x-ui panel.
* `node-docker`: Install Docker Engine and Compose.
* `node-exporter`: Deploy Prometheus Node Exporter.

## Role Variables

### Service Toggles
Set to `true` to enable a specific service:
| Variable | Default | Variable | Default |
|---|---|---|---|
| `node_singbox_install` | `false` | `node_docker_enabled` | `true` |
| `node_gost_install` | `false` | `node_exporter_install` | `true` |
| `node_xui_install` | `false` | `node_bootstrap_enabled` | `true` |

*(Note: Every `_install` variable has a corresponding `_enabled` variable to control the systemd service state).*

### Key Configurations
* **Docker (`node_docker_bip`)**: Defines the default bridge IP to prevent subnet conflicts.
* **X-UI (`node_xui_port`, `node_xui_web_base_path`)**: Defines the panel's administrative access points.
* **Sing-box (`node_singbox_outbounds`)**: Accepts raw v2ray links or standard JSON configurations.

## Example Playbook

```yaml
- name: Setup Node Services
  hosts: proxies
  vars:
    # Docker Configuration
    node_docker_enabled: true
    node_docker_bip: "172.29.0.1/16"
    node_docker_default_address_pools:
      - base: "172.30.0.0/16"
        size: 24

    # Sing-box Tunneling
    node_singbox_install: true
    node_singbox_enabled: true
    node_singbox_mixed_listen: "127.0.0.1"
    node_singbox_mixed_port: 10808
    node_singbox_outbounds:
      links:
        - "vless://uuid@server:443?security=tls#my-proxy"
      selectors:
        - tag: auto
          type: urltest
          use_all_links: true

    # Monitoring
    node_exporter_install: true
    node_exporter_enabled: true
    node_exporter_enabled_collectors:
      - systemd
      - processes

  roles:
    - ahmz.server_setup.node
```

## License
MIT

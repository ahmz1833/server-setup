# Ansible role: `ahmz1833.server_setup.k3s`

A production-ready, property-driven, and highly composable Ansible role to provision, manage, scale, and operate **K3s clusters** across any arbitrary topology (Single-Node, Multi-Master HA with embedded etcd or external datastore, and dedicated worker agents). Binaries are deployed idempotently via the **`ahmz1833.server_setup.asset`** role.

Designed for **systemd** Linux. **Gather facts** must be enabled so host architecture, default IPs, and OS facts are properly resolved.

---

## Requirements

| Requirement | Notes |
|-------------|--------|
| **Collection** | This role lives in `ahmz1833.server_setup`; install the collection and its declared dependencies (`community.general`, `community.crypto`, `ansible.posix`, …). |
| **Role dependency** | **`asset`** (declared in `meta/main.yml`) for K3s binary downloads and local caching. |
| **Target OS** | **systemd** Linux (Debian, Ubuntu, RHEL/Fedora family); privilege escalation (`become: true`) required for service units, firewall rules, and `/etc/rancher/k3s` configuration. |
| **Facts** | `gather_facts: true` required (`ansible_facts['nodename']`, default IPv4/v6 addresses, and OS family). |

---

## Playbook-level variables (consumed via defaults)

| Playbook var | Maps to | Purpose |
|--------------|---------|---------|
| `is_iran` | `k3s_internet_restricted` | Offline mirror toggles (`k3s_dockerhub_mirror`, `system-default-registry`, `pause-image`). |
| `download_locally` | `k3s_download_locally` | Passed to **`asset`** role (stage binary on control node, push to target host). |
| `enable_ipv6` | `k3s_enable_ipv6` | Dual-stack IPv6 firewall and node address resolution. |

---

## Task order and tags

`tasks/main.yml` runs in two execution branches depending on `k3s_state`:

### Provisioning & Management Branch (`k3s_state: present`)
1. **validate** — Assert node execution mode, server datastore role, and inventory group existence (`validate/main.yml`).
2. **install** — Remove legacy env files and deploy K3s binary asset via **`asset`** role (`install/main.yml`).
3. **configure** — Render `/etc/rancher/k3s/k3s.env`, systemd service units, and `/etc/rancher/k3s/config.yaml` (`configure/main.yml`).
4. **firewall** — Assemble and merge K3s port rules into `core` firewall role (`firewall/main.yml`).
5. **hosts bootstrap** — Temporarily add `k3s_control_plane_domain` to `/etc/hosts` for joining nodes (`tasks/main.yml`).
6. **cluster** — Bootstrap primary control plane (`server_init.yml`), join secondary servers (`server_join.yml`), or join worker agents (`agent.yml`).
7. **manifests** — Deploy Traefik `HelmChartConfig` and user-defined Kubernetes YAML manifests (`manifests/main.yml`).
8. **hosts cleanup** — Remove temporary `/etc/hosts` bootstrap entry in `always:` block (`tasks/main.yml`).

### Operational Day 2 Branch (`k3s_state != present`)
1. **validate** — Validate node and cluster facts (`validate/main.yml`).
2. **day2** — Execute specified operation (`drain`, `uncordon`, `rotate-certs`, `fetch-kubeconfig`, `uninstall`).

| Tag | Scope |
|-----|--------|
| `k3s` | Entire role |
| `k3s-validate` | Configuration and inventory schema assertions |
| `k3s-install` | K3s binary asset installation |
| `k3s-configure` | Config files and systemd service unit rendering |
| `k3s-firewall` | K3s firewall rule generation and core role invocation |
| `k3s-cluster` | Cluster bootstrapping, token resolution, and server/agent joining |
| `k3s-manifests` | Traefik HelmChartConfig and custom manifest deployment |
| `k3s-day2` | Day 2 cluster operations (drain, uncordon, cert rotation, fetch kubeconfig, uninstall) |

---

## Role Variables

### Cluster Metadata & Lifecycle

| Variable | Default | Description |
| :--- | :--- | :--- |
| `k3s_state` | `"present"` | Operational state (`present`, `absent`, `uninstall`, `drain`, `uncordon`, `rotate-certs`, `fetch-kubeconfig`). |
| `k3s_force_uninstall` | `false` | Guard safety flag required to execute `absent` / `uninstall` uninstallation state. |
| `k3s_drain_ignore_errors` | `false` | Ignore errors during node drain operations. |
| `k3s_drain_timeout` | `"300s"` | Timeout for `kubectl drain` commands during node draining/decommissioning. |
| `k3s_cluster_name` | `"k3s"` | Name of the cluster used in metadata, tags, and kubeconfig contexts. |
| `k3s_version` | `"v1.36.3+k3s1"` | Target K3s release version. |

### Topology & Node Roles

| Variable | Default | Description |
| :--- | :--- | :--- |
| `k3s_role` | `"server"` | Node mode: `server` (control plane) or `agent` (worker). |
| `k3s_datastore_role` | `"standalone"` | Datastore mode for servers: `standalone`, `cluster-init`, or `join`. |
| `k3s_control_plane_group` | `"k3s_servers"` | Inventory group name representing K3s server nodes. |
| `k3s_agent_group` | `"k3s_agents"` | Inventory group name representing K3s agent worker nodes. |
| `k3s_token` | `""` | Registration token (auto-discovered via `slurp` from primary server if empty). |

### Network & Endpoint Settings

| Variable | Default | Description |
| :--- | :--- | :--- |
| `k3s_https_listen_port` | `6443` | API Server local HTTPS listen port. |
| `k3s_control_plane_domain` | `""` | Optional external DNS domain for control plane load balancing (e.g. `"api.k8s.example.com"`). Automatically included in TLS SANs and `/etc/hosts` temporary setup. |
| `k3s_control_plane_port` | `6443` | Optional external port for control plane load balancing (defaults to `k3s_https_listen_port`). |
| `k3s_bind_address` | `""` | IP address to bind K3s supervisor/API server listener to. |
| `k3s_node_ip` | `""` | IP address to advertise for node (auto-resolved if empty). |
| `k3s_node_name` | `""` | Target node name in Kubernetes (auto-resolved from nodename/hostname if empty). |
| `k3s_cluster_cidr` | `"10.42.0.0/16"` | IPv4 pod network CIDR range. |
| `k3s_service_cidr` | `"10.43.0.0/16"` | IPv4 service ClusterIP CIDR range. |
| `k3s_flannel_backend` | `"vxlan"` | Flannel CNI backend (`vxlan`, `host-gw`, `wireguard-native`, `none`). |
| `k3s_tls_sans` | `[]` | Additional Subject Alternative Names (SANs) for API server certificate. |

### Component & Ingress Control

| Variable | Default | Description |
| :--- | :--- | :--- |
| `k3s_disable_servicelb` | `false` | Disable built-in Klipper ServiceLB. |
| `k3s_disable_traefik` | `false` | Disable built-in Traefik ingress. |
| `k3s_disable_components` | `[]` | List of built-in components to disable (e.g. `["local-storage", "metrics-server"]`). |
| `k3s_traefik_config` | `{...}` | Custom Traefik `HelmChartConfig` port definitions. Supports `service.type` (`'LoadBalancer'`, `'ClusterIP'`, `'NodePort'`), `ports.web/websecure.port`, `exposedPort`, `hostPort`, and optional explicit `nodePort` (e.g. `30080` / `30443`). |
| `k3s_node_labels` | `{}` | Key-value dictionary of node labels. |
| `k3s_node_taints` | `[]` | List of node taints (e.g. `["node-role.kubernetes.io/control-plane=true:NoSchedule"]`). |
| `k3s_config` | `{}` | Arbitrary extra key-value pairs rendered into `/etc/rancher/k3s/config.yaml`. |
| `k3s_env` | `{}` | Arbitrary extra environment variables rendered into `/etc/rancher/k3s/k3s.env`. |
| `k3s_manifests` | `[]` | List of additional Kubernetes YAML manifests to deploy into `/var/lib/rancher/k3s/server/manifests/`. |

### Offline / Mirror Registry Settings

| Variable | Default | Description |
| :--- | :--- | :--- |
| `k3s_dockerhub_mirror` | `"hub.hamdocker.ir"` | Docker Hub mirror hostname used when `k3s_internet_restricted` is enabled. |
| `k3s_system_default_registry` | `""` | Registry used for system chart images and sandbox pause image. Defaults to `k3s_dockerhub_mirror` when restricted. Applied via k3s-native `system-default-registry` key on servers. |
| `k3s_pause_image` | `""` | Sandbox pause image ref. Defaults to `<k3s_system_default_registry>/rancher/mirrored-pause:3.6`. Applied via `pause-image` key on all nodes. |

```yaml
# Effective config.yaml on a server node when is_iran is enabled:
system-default-registry: "hub.hamdocker.ir"
pause-image: "hub.hamdocker.ir/rancher/mirrored-pause:3.6"
```

### Firewall Integration Settings

| Variable | Default | Description |
| :--- | :--- | :--- |
| `k3s_firewall_manage` | `true` | Expose K3s firewall rules to the `core` firewall role. |
| `k3s_firewall_enable_nodeport` | `false` | Open NodePort service range in host firewall. |
| `k3s_firewall_nodeport_range` | `"30000-32767"` | NodePort TCP/UDP port range to open when enabled. |
| `k3s_firewall_allowed_api_cidrs` | `["0.0.0.0/0"]` | Whitelisted CIDRs allowed to access K3s API server port (`6443`). |
| `k3s_firewall_allowed_ingress_cidrs` | `["0.0.0.0/0"]` | Whitelisted CIDRs allowed to access Traefik ingress ports (`80/443` or custom `18080/18443`). Set to `[]` to prevent opening public ports. |
| `k3s_firewall_allowed_etcd_cidrs` | `[]` | Whitelisted CIDRs for etcd client/peer ports (`2379/2380`). Defaults to all control plane node IPs. |
| `k3s_firewall_allowed_kubelet_cidrs` | `[]` | Whitelisted CIDRs for Kubelet API port (`10250`). Defaults to all cluster node IPs. |

---

## Deep Dive: ServiceLB, Ports, & Ingress Exposure

### What is ServiceLB (Klipper LB)?

ServiceLB is K3s's built-in, lightweight Layer 4 (TCP/UDP) load balancer controller.
- **How it works**: When a Service of `type: LoadBalancer` is created (such as Traefik Ingress), ServiceLB deploys daemonset proxy pods (`rancher/klipper-lb`) across cluster nodes that bind host ports `80` & `443` on physical host interfaces and forward incoming traffic to the target pods.
- **When to keep enabled (`k3s_disable_servicelb: false`)**: Standalone VPS or simple multi-worker clusters where K3s owns public ports `80/443`.
- **When to disable (`k3s_disable_servicelb: true`)**:
  1. When running a host-level Nginx / Apache web server on the same node (prevents port 80/443 collisions).
  2. When using external HAProxy / Nginx load balancers with `NodePort` (`30080`/`30443`).
  3. When using MetalLB or BGP Virtual IPs in bare-metal datacenters.

### Port Definitions in Traefik Ingress

| Port Name | Layer | Purpose & Example |
| :--- | :--- | :--- |
| **`port`** | Inside Container | Internal port Traefik process binds to inside pod (default: `8000` HTTP, `8443` HTTPS). |
| **`exposedPort`** | K8s Service | Virtual port published by the Kubernetes Service (default: `80` HTTP, `443` HTTPS). |
| **`hostPort`** | Physical Host Node | Binds directly to physical node network interface (e.g. `18080`, `18443`). |
| **`nodePort`** | Node IP Range | Cluster-wide port in `30000–32767` range accessible on all node IPs (e.g. `30080`, `30443`). |

### Ingress Exposure Strategies

#### 1. Default Public Ingress (`LoadBalancer` + ServiceLB)
- **Config**: `k3s_disable_servicelb: false`
- **Flow**: `Internet` ➔ `Node IP:80/443` ➔ `Klipper LB` ➔ `Traefik Pod` ➔ `Application Pod`
- **Use Case**: Default single-node VPS or simple multi-worker setup.

#### 2. Host Nginx Reverse Proxy (Host Coexistence)
- **Config**: `k3s_disable_servicelb: true`, `hostPort: 18080` / `hostPort: 18443`, `exposedPort: 80` / `443`
- **Flow**: `Internet` ➔ `Host Nginx (80/443)` ➔ `127.0.0.1:18080 / 18443` ➔ `Traefik Pod (exposedPort 80/443)` ➔ `Application Pod`
- **Use Case**: Running host web applications (PHP, X-UI, legacy sites) alongside K3s on the same node without public port exposure. `exposedPort` remains standard `80/443` for in-cluster K8s services, while `hostPort` handles local Nginx proxying.

#### 3. NodePort + External HAProxy Load Balancer
- **Config**: `k3s_disable_servicelb: true`, `service.type: NodePort`, `nodePort: 30080`, `k3s_firewall_enable_nodeport: true`
- **Flow**: `Internet` ➔ `External HAProxy (80/443)` ➔ `Node IP:30080` ➔ `Traefik Pod` ➔ `Application Pod`
- **Use Case**: High-availability production clusters with external load balancing and strict firewall isolation (`k3s_firewall_allowed_ingress_cidrs: ["<HAProxy_IP>/32"]`).

---

## Topology Examples

### 1. Single-Node All-in-One + Host Nginx Coexistence

```yaml
k3s_servers:
  hosts:
    edge-node-1:
      ansible_host: 192.168.1.10
      k3s_role: "server"
      k3s_datastore_role: "standalone"
      # Prevent ServiceLB from hijacking host 80/443 so host Nginx can bind to them
      k3s_disable_servicelb: true
      k3s_traefik_config:
        enabled: true
        ports:
          web: { port: 8000, exposedPort: 80, hostPort: 18080 }
          websecure: { port: 8443, exposedPort: 443, hostPort: 18443 }
```

### 2. Multi-Master HA (Embedded etcd) + Worker Agents

```yaml
k3s_servers:
  hosts:
    master-1:
      ansible_host: 10.0.0.11
      k3s_role: "server"
      k3s_datastore_role: "cluster-init"
      k3s_node_taints:
        - "node-role.kubernetes.io/control-plane=true:NoSchedule"
    master-2:
      ansible_host: 10.0.0.12
      k3s_role: "server"
      k3s_datastore_role: "join"
      k3s_node_taints:
        - "node-role.kubernetes.io/control-plane=true:NoSchedule"
    master-3:
      ansible_host: 10.0.0.13
      k3s_role: "server"
      k3s_datastore_role: "join"
      k3s_node_taints:
        - "node-role.kubernetes.io/control-plane=true:NoSchedule"

k3s_agents:
  hosts:
    worker-1:
      ansible_host: 10.0.0.21
      k3s_role: "agent"
      k3s_node_labels:
        environment: production
```

### 3. NodePort Ingress + External Load Balancer (HAProxy / Cloud LB)

```yaml
k3s_servers:
  hosts:
    server-1:
      ansible_host: 10.0.0.11
      k3s_role: "server"
      k3s_datastore_role: "standalone"
      k3s_disable_servicelb: true
      k3s_traefik_config:
        enabled: true
        service:
          type: "NodePort"
        ports:
          web: { port: 8000, exposedPort: 80, nodePort: 30080 }
          websecure: { port: 8443, exposedPort: 443, nodePort: 30443 }
      # Open NodePort range (30000-32767) in host firewall:
      k3s_firewall_enable_nodeport: true
```

---

## Playbook Usage & Operational Lifecycle

### Day 0 & Day 1: Deploy & Scale Cluster
```yaml
- name: Deploy K3s Cluster
  hosts: k3s_servers:k3s_agents
  become: true
  roles:
    - role: ahmz1833.server_setup.core
    - role: ahmz1833.server_setup.k3s
      vars:
        k3s_state: present
```

### Day 2: Decommission Node safely
```yaml
- name: Remove Node from Cluster
  hosts: worker-2
  become: true
  roles:
    - role: ahmz1833.server_setup.k3s
      vars:
        k3s_state: absent
        k3s_force_uninstall: true
```

> **Note**: `k3s_state: uninstall` is an alias of `absent`.

## Upgrading K3s

Upgrades are version-driven: bump `k3s_version` and re-run the role (see `examples/rolling-upgrade.yml` for a rolling server/agent sequence). The binary is replaced in place by the `asset` role and the cluster is upgraded in place.

> **Note**: `k3s_cluster_cidr` / `k3s_service_cidr` / `k3s_flannel_backend` are only rendered on `server` nodes and are **immutable after first boot**. Changing them on an existing cluster requires re-provisioning the cluster.

---

## License

MIT

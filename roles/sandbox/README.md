# Ansible Role: ahmz.server_setup.sandbox

Provides fully isolated, container-backed terminal environments via SSH.

## Description

The `sandbox` role allows you to safely provide external users with a terminal experience on your server. Instead of creating host-level Linux users, it sets up a single secure SSH endpoint that intercepts incoming connections, maps the user's SSH key to a specific identity, and traps them instantly inside a dedicated Docker container.

### Core Capabilities
* **Hardened Isolation:** Incoming users never get a host shell. They are mapped seamlessly into their respective container via an isolated wrapper.
* **Native Shell Experience:** Retains full PTY support, passes `TERM` and `LANG` correctly, and allows custom default shells (e.g., `/bin/zsh`) for a flawless terminal experience including full color and key mapping.
* **Auto-Bootstrapping:** Automatically injects the exact host UID/GID mapping and installs passwordless `sudo` directly into the container upon creation, resolving "I have no name!" errors and preserving native file permissions on shared volumes.
* **Port Segregation:** Listens on a dedicated SSH port (e.g., `2222`), separating sandbox traffic from administrative SSH traffic on port `22`.
* **Tunneling Denied:** Explicitly blocks SSH port forwarding and X11 forwarding at the SSH daemon and `authorized_keys` level to prevent internal network scanning.
* **App Role Parity:** Supports defining container resources, volumes, networks, and exposed ports natively.

## Requirements

* **Firewall Configuration:** The `sandbox_ssh_port` must be explicitly permitted through the server's firewall (e.g., added to `core_firewall_rules`).

## Role Variables

### Global Configuration

| Variable | Description | Default | 
| ----- | ----- | ----- | 
| `sandbox_managed` | Master toggle to enable/disable the sandbox setup. | `true` | 
| `sandbox_ssh_port` | Dedicated port for incoming sandbox SSH connections. | `2222` | 
| `sandbox_shared_user` | Name of the locked host user managing the connections. | `"sandbox"` | 

### Virtual Users (`sandbox_users`)

The `sandbox_users` variable defines the mapped identities and their container parameters.

| Key | Type | Description | 
| ----- | ----- | ----- | 
| `name` | String | **(Required)** Identifier for the virtual user. | 
| `image` | String | Docker image to use for the sandbox environment. | 
| `shell` | String | Default shell to execute inside the container (e.g., `/bin/zsh`). | 
| `ssh_keys` | List | **(Required)** List of raw public SSH keys permitted to access this container. | 
| `ports` | List | Port bindings (e.g., `["127.0.0.1:8081:80"]`). | 
| `volumes` | List | Volume bindings (e.g., `["/opt/data/guest1:/workspace"]`). | 
| `env` | Dict | Environment variables injected into the sandbox. | 
| `networks` | List | Docker networks to attach to the container. | 
| `memory` / `cpus` | String/Float | Hard resource limits for the sandbox container. | 

## Example Playbook

```yaml
- name: Deploy Sandbox Environments
  hosts: servers
  vars:
    # Ensure the firewall allows the sandbox port
    core_firewall_rules:
      - { port: 2222, comment: "Sandbox SSH" }
      - { port: 80, comment: "HTTP" }
      - { port: 443, comment: "HTTPS" }
      
    sandbox_managed: true
    sandbox_ssh_port: 2222
    sandbox_users:
      - name: "developer1"
        image: "ghcr.io/YOUR_GITHUB_USERNAME/sandbox-base:latest"
        shell: "/bin/zsh"
        ssh_keys:
          - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
        volumes:
          - "/opt/sandbox_data/dev1:/workspace"
        ports:
          - "127.0.0.1:8081:8080"
        memory: "512m"
        cpus: 0.5
        
    # Proxy developer1's web service using the nginx role
    nginx_sites:
      - domain: "dev1.example.com"
        upstream: "[http://127.0.0.1:8081](http://127.0.0.1:8081)"
  roles:
    - ahmz.server_setup.core
    - ahmz.server_setup.sandbox
    - ahmz.server_setup.nginx
```

## How It Works

1. User connects via `ssh developer1@server -p 2222`.
2. SSHD authenticates via the mapped key in `authorized_keys`.
3. A forced command (`command="sudo /usr/local/bin/sandbox-login.sh developer1 /bin/zsh"`) immediately intercepts the session.
4. The wrapper drops the user into the `sandbox-developer1` Docker container, passing the correct `$TERM`, `$LANG`, and `$UID` environments natively.

## License

MIT

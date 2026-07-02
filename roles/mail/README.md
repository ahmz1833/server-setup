# Ansible role: `ahmz1833.server_setup.mail`

Idempotent deployment of a secure mail server using `docker-mailserver` and `SnappyMail` as a webmail client.

Features include DKIM/DMARC/SPF setup, automated user management (Single Source of Truth), and admin spoofing capabilities.

---

## Requirements

| Requirement | Notes |
|-------------|--------|
| **Ansible** | 2.14+ (`meta/main.yml`). |
| **Collections** | `community.docker` |
| **Target** | Linux with **Docker** installed and running. |

---

## Role entrypoint and tasks

`tasks/main.yml` order:

1. **setup** — Creates directories and Docker networks for the mailserver.
2. **deploy** — Deploys `docker-mailserver` and `snappymail` containers.
3. **dkim** — Generates and extracts DKIM keys idempotently.
4. **users** — Syncs users and passwords securely from Ansible variables to the mailserver, deleting unmanaged users. Also sets up admin spoofing maps.
5. **webmail** — Configures SnappyMail admin password securely and idempotently, along with custom admin panel paths.
6. **dns** — Prompts the user with a clean, copy-pasteable set of required DNS records (A, MX, TXT for SPF/DMARC/DKIM).

---

## Notable defaults (see `defaults/main.yml` for the full list)

### Domains and Hostnames

| Variable | Default | Description |
|----------|---------|-------------|
| `mail_domain` | `"example.com"` | Primary domain for the mailserver |
| `mail_hostname` | `"mail.example.com"` | FQDN of the mailserver |

### Users and Passwords

The role enforces a Single Source of Truth (SSoT) for mail users. Passwords are set and updated idempotently using native Dovecot bcrypt verification.

| Variable | Default | Description |
|----------|---------|-------------|
| `mail_admin_username` | `"admin"` | Username for the admin mail account. Can spoof any sender. |
| `mail_admin_password` | `"CHANGEME"` | Password for the admin mail account. |
| `mail_noreply_sender` | `"noreply"` | Username for the noreply account. |
| `mail_noreply_password` | `"CHANGEME"` | Password for the noreply account. |
| `mail_users` | `[]` | List of dictionaries (`username` and `password`) for standard users. |
| `mail_users_whitelist_regex` | `"^$"` | Regex to protect existing unmanaged users from deletion. (e.g. `^(postmaster\|hostmaster)$`) |

### SnappyMail (Webmail)

| Variable | Default | Description |
|----------|---------|-------------|
| `mail_webmail_admin_password` | `"CHANGEME"` | Password for SnappyMail admin panel |
| `mail_webmail_admin_path` | `"admin"` | Secret URL path for the SnappyMail admin panel |
| `mail_snappymail_force_reset_admin` | `false` | Set to `true` to forcefully overwrite SnappyMail admin credentials with Ansible variables, bypassing UI changes. |

---

## Example playbook

```yaml
- name: Mail setup
  hosts: all
  become: true
  vars:
    mail_domain: "neda-event.ir"
    mail_hostname: "mail.neda-event.ir"
    mail_admin_username: "admin"
    mail_admin_password: "SecureAdminPassword123"
    mail_noreply_sender: "noreply"
    mail_noreply_password: "SecureNoReplyPassword456"
    mail_users:
      - username: "user1"
        password: "user1pass"
  roles:
    - role: ahmz1833.server_setup.mail
```

---

## Handlers

- **Restart mailserver** — Restarts the `docker-mailserver` container if DKIM keys or user patches have been generated/modified.

---

## License

MIT

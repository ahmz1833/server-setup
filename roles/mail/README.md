# Ansible role: `ahmz1833.server_setup.mail`

Idempotent deployment of a secure mail server using `docker-mailserver` and `SnappyMail` as a webmail client.

Features include DKIM/DMARC/SPF setup, automated user management (Single Source of Truth), and admin spoofing capabilities.

---

## Requirements

| Requirement | Notes |
|-------------|--------|
| **Ansible** | 2.14+ (`meta/main.yml`). |
| **Collections** | `community.docker` |
| **Target** | Linux with **Docker** installed and running (the `node` role does this). |
| **TLS certificate** | `/etc/ssl/certs/<mail_domain>/{fullchain,privkey}.pem` must exist **before** this role runs — the container is deployed with `SSL_TYPE=manual` pointing at exactly those paths and is bind-mounted read-only. Issue them with the `acme` role for `mail.<domain>` first; without them the mailserver starts with no usable TLS and submission on 587/465 fails. |
| **Open ports** | 25 (MX), 465 (implicit TLS), 587 (submission), 993 (IMAPS). This role does **not** manage the firewall — add them to `core_firewall_rules`. Note that many hosting providers block outbound 25 by default, which breaks delivery rather than reception. |
| **DNS** | A record for the host, MX, SPF, DMARC and the DKIM TXT record the role prints at the end of a run. Mail from a domain with no SPF/DKIM alignment is filed as spam by most receivers — the run is not finished until those records exist. |
| **Reverse DNS** | The provider's PTR for the host's IP should resolve to `mail_hostname`. Receivers check it, and it is the one record that cannot be set from here. |

### Sending from inside another system

The `noreply` account exists to be used as an SMTP client credential by an
application (`mail_noreply_sender` / `mail_noreply_password`): connect to
`mail_hostname` on **587 with STARTTLS**, authenticate as
`noreply@<mail_domain>`, and send `From:` that same address. `SPOOF_PROTECTION`
is on, so an account may only send as itself — the single exception is the admin
account, which the role maps as allowed to spoof any sender.

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

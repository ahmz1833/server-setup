# Toolchain: running a project anywhere

A project built on this standard runs on any machine with `make` and either Python 3.11+
(or `uv`) or Docker. Nothing needs to be pre-installed.

## `make setup` → `scripts/ensure-toolchain.sh`

Idempotent; run it whenever you start working (it is cheap when everything is present).

1. **Ansible**: uses `./.venv` if it works; else a system `ansible-playbook` if it works
   (`USE_VENV=1` to skip that); else creates `./.venv` from `requirements.txt` — with `uv`
   if available (downloads a Python if needed), otherwise `python3 -m venv`.
   Broken interpreters (e.g. dangling pyenv shims, unsupported versions) are detected and
   skipped.
2. **Collections**: `ansible-galaxy collection install -r requirements.yml -p ./collections --upgrade`
   — i.e. **the latest `ahmz1833.server_setup`** and its dependencies, installed
   project-locally so a user-wide copy never masks it. If Galaxy is unreachable it falls
   back to the GitHub repository.
3. Prints the ansible and collection versions.
4. **Agent skills**: if no agent on this machine has `infra-iac` (checked in `~/.claude`,
   `~/.agents`, `~/.codex`, `~/.cursor`, Claude Code plugins, and the project), installs them
   user-wide with `npx skills add ahmz1833/server-setup` (best-effort; needs node/npx;
   `SKIP_SKILLS=1` to skip). If you prefer the Claude Code plugin, install it once and the
   check finds it.

| Env var | Effect |
|---|---|
| `SERVER_SETUP_VERSION=1.5.0` | pin the collection (reproducible runs, CI) |
| `NO_UPGRADE=1` | keep what is installed |
| `COLLECTION_SRC=../server-setup` | symlink a local checkout of the collection (co-develop a role and the project together) |
| `USE_VENV=1` | ignore system ansible |
| `PYTHON=python3.12` | interpreter for the venv |
| `SKIP_SKILLS=1` | don't install the AI agent skills |

The Makefile then uses `.venv/bin/*` when present and sets
`ANSIBLE_COLLECTIONS_PATH=./collections:~/.ansible/collections:/usr/share/ansible/collections`.

## sudo password

If the admin user needs a password for sudo, put it in a local file — every ansible command
of the Makefile then passes it with `--become-password-file` and never prompts. First found
wins: `.become_pass.<env>`, `.become-pass.<env>`, `.become_pass`, `.become-pass` (or
`BECOME_FILE=<path>`). Keep it `chmod 600`; it is gitignored. Without a file, `BECOME_ASK=1`
prompts; with neither, passwordless sudo is assumed.

```bash
umask 077; read -rs -p 'sudo password: ' p && printf '%s\n' "$p" > .become_pass; unset p
```

## Working on servers: `make shell`, `make module`, `make var`

Addresses, ports, users and keys are resolved from the inventory and vault — you never type
(or see) them.

```bash
make shell H=web-1                           # interactive SSH session on one host
make shell H=web -- df -h                    # run a command on one or many hosts (sudo)
make shell H=web-1 CMD='grep -c "a=b" /etc/x' # use CMD= when the command contains '=' or quotes
make shell H=web-1 SUDO=0 -- id              # as the login user instead of root
make shell H=web ENV=staging -- uptime       # another environment
make module H=web-1 M=ansible.builtin.setup A='filter=ansible_mem*'   # any Ansible module
make var H=web-1 V=nginx_sites               # templated value of a variable (vault_* refused)
make docker-logs H=web-1 C=app SINCE=10m     # container logs (no C = list containers)
```

- `H` is any Ansible host pattern (`web-1`, `web`, `web:&loc_iran`, `all`). The interactive
  form needs exactly one host.
- Commands run through `ansible.builtin.shell`, so pipes and redirects work. They run as
  root unless `SUDO=0`.
- Words after `--` are the command and never make targets — `make shell H=x -- echo apply`
  is safe.
- Extra Ansible options (async, verbosity, forks): `EXTRA='-B 300 -P 0'`, `EXTRA=-vvv`.

## Without Python: Docker runner

```bash
make docker-shell            # ghcr.io/ahmz1833/server-setup:latest, repo mounted at /work
# inside:
make check LIMIT=web-1
```

The image contains ansible-core, the collection (matching the image tag) and its
dependencies, `make`, `git` and `openssh-client`. Your `~/.ssh` is mounted read-only.
Pin a version with `IMAGE=ghcr.io/ahmz1833/server-setup:1.5.0`.

## Without a project at all

To look something up: `ansible-doc -t role ahmz1833.server_setup.<role>` (after
`ansible-galaxy collection install ahmz1833.server_setup`), the role READMEs on GitHub, or
[roles-index.md](roles-index.md).

## Where things are after setup

| Thing | Path |
|---|---|
| Collection source (roles, defaults, templates) | `collections/ansible_collections/ahmz1833/server_setup/roles/<role>/` |
| Collection docs (this file, security, operations…) | `collections/ansible_collections/ahmz1833/server_setup/docs/` |
| Full example projects | `collections/ansible_collections/ahmz1833/server_setup/examples/` |
| Variable reference | `.../docs/roles-index.md` or `ansible-doc -t role ahmz1833.server_setup.<role>` |

## Offline validation

`make validate` runs every play with `--tags __argspec_only__` against `localhost`: only
fact gathering (local) and the roles' argument-spec validation execute. It catches typos
in types and structure of collection variables without contacting any server.
Unknown top-level variable names are not reported (Ansible only validates declared
options) — check names against roles-index.

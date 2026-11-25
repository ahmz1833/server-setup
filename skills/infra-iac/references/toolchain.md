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

## `make shell`

Runs with the project's environment: `.venv/bin` on `PATH`, `ANSIBLE_INVENTORY` = the
current `ENV`'s inventory, `ANSIBLE_VAULT_IDENTITY_LIST` = the resolved vault ids, plus the
project's `ANSIBLE_CONFIG`/collections path. Plain `ansible*` commands then just work:

```bash
make shell                                   # interactive; `exit` to leave
make shell -- ansible-inventory --graph      # one command
make shell -- ansible web -m ping
make shell CMD='ansible web-1 -b -a "df -h"' # use CMD= when args contain '=' or quotes
make shell ENV=staging -- ansible all -m ping
```

In shell mode the words after `shell` are never treated as make targets.

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

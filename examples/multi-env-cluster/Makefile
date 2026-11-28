# Infra Makefile — standard from ahmz1833/server-setup (examples/starter).
# Run `make help`. Every playbook target accepts:
#   ENV=<env>  LIMIT=<host|group>  TAGS=<t1,t2>  SKIP=<tags>  EXTRA="<more ansible args>"
# Work on the servers (inventory + vault resolve addresses, ports, users for you):
#   make shell H=web-1                         interactive SSH session on one host
#   make shell H=web -- df -h                  run a command on one or many hosts (sudo)
#   make shell H=web CMD='grep -c "a=b" /f'    use CMD= when the command has '=' or quotes
#   make shell H=web-1 SUDO=0 -- id            run as the login user instead of root
#   make module H=web-1 M=ansible.builtin.setup A='filter=ansible_mem*'   any Ansible module
#   make var H=web-1 V=nginx_sites             a variable's templated value on a host
#   make ssh-config [REPLACE=1]                write/refresh this project's hosts in ~/.ssh/config
.DEFAULT_GOAL := help

ENV       ?= prod
INV       := inventories/$(ENV)
PLAY      ?= site
LIMIT     ?=
TAGS      ?=
SKIP      ?=
EXTRA     ?=
H         ?=
KEY       ?=
C         ?=
N         ?= 200
SINCE     ?=
LEN       ?=
SHOW_VAULT ?= 0
REPLACE   ?= 0
SSH_CONFIG ?= ~/.ssh/config
PROJECT   ?= $(notdir $(CURDIR))
SUDO      ?= 1
M         ?=
A         ?=
V         ?=
FILE      ?= $(INV)/group_vars/all/vault.yml
IMAGE     ?= ghcr.io/ahmz1833/server-setup:latest
# Vault password, resolved in this order:
#   VAULT_IDS="prod@.vault_pass.prod ..."  explicit vault ids (space separated)
#   .vault_pass.$(ENV)                     per-environment password file (label = ENV)
#   .vault_pass                            single password file (label = default)
#   prompt                                 if the inventory has encrypted files
# VAULT_PER_ENV=1 makes `vault-init` create .vault_pass.$(ENV) instead of .vault_pass.
VAULT_IDS     ?=
VAULT_PER_ENV ?= 0
# sudo password: a local file is used automatically (never prompts), first found of
#   .become_pass.$(ENV)  .become-pass.$(ENV)  .become_pass  .become-pass   (gitignored, mode 600)
# otherwise BECOME_ASK=1 prompts; with neither, passwordless sudo is assumed.
BECOME_ASK ?= 0
BECOME_FILE ?= $(firstword $(wildcard .become_pass.$(ENV) .become-pass.$(ENV) .become_pass .become-pass))
BECOME_ARGS := $(if $(BECOME_FILE),--become-password-file $(BECOME_FILE),$(if $(filter 1,$(BECOME_ASK)),--ask-become-pass))

comma := ,
# `make shell H=… -- <cmd>`: the words after `shell` are the command, not make targets.
ifeq (shell,$(firstword $(MAKECMDGOALS)))
  SHELL_MODE := 1
  SHELL_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
endif
CMD ?= $(SHELL_ARGS)
BIN := $(if $(wildcard .venv/bin/ansible-playbook),.venv/bin/,)
PY  := $(if $(BIN),$(BIN)python,python3)
TOOLS := $(PY) scripts/infra-tools.py
# project-local collections first; image/system paths as fallback (docker-shell)
export ANSIBLE_COLLECTIONS_PATH := $(CURDIR)/collections:$(HOME)/.ansible/collections:/usr/share/ansible/collections
export ANSIBLE_CONFIG := $(CURDIR)/ansible.cfg

HAS_VAULT   := $(shell grep -rlsq '^\$$ANSIBLE_VAULT' $(INV) && echo yes)
VAULT_FILE  := $(firstword $(wildcard .vault_pass.$(ENV)) $(wildcard .vault_pass))
VAULT_LABEL := $(if $(wildcard .vault_pass.$(ENV)),$(ENV),default)
ifneq ($(strip $(VAULT_IDS)),)
  VAULT_ARGS := $(foreach v,$(VAULT_IDS),--vault-id $(v))
  VAULT_ID   := $(firstword $(VAULT_IDS))
else
  VAULT_ID   := $(VAULT_LABEL)@$(or $(VAULT_FILE),prompt)
  VAULT_ARGS := $(if $(HAS_VAULT),--vault-id $(VAULT_ID))
endif
# id used by vault-init when creating new files
INIT_FILE := $(if $(filter 1,$(VAULT_PER_ENV)),.vault_pass.$(ENV),.vault_pass)
INIT_ID   := $(if $(strip $(VAULT_IDS)),$(firstword $(VAULT_IDS)),$(if $(filter 1,$(VAULT_PER_ENV)),$(ENV),default)@$(INIT_FILE))

# ad-hoc commands on hosts
HOSTARGS := -i $(INV) $(VAULT_ARGS) $(BECOME_ARGS) $(EXTRA)
BECOME   := $(if $(filter 1,$(SUDO)),-b)
squote    = $(subst ','\'',$(1))

ARGS := -i $(INV) $(VAULT_ARGS) \
  $(if $(LIMIT),--limit '$(LIMIT)') $(if $(TAGS),--tags '$(TAGS)') \
  $(if $(SKIP),--skip-tags '$(SKIP)') $(BECOME_ARGS) $(EXTRA)

.PHONY: help setup skills shell module var ssh-config validate check apply run ping host docker-logs graph vault-init vault-edit vault-view vault-keys vault-gen vault-check lint docker-shell

shell: ## On servers: `make shell H=<host>` = SSH session; `make shell H=<host|group> -- <cmd>` or CMD='<cmd>' [SUDO=0]
	@test -n "$(H)" || { echo "usage: make shell H=<host|group> [-- <cmd> | CMD='<cmd>'] [SUDO=0]"; exit 1; }
ifneq ($(strip $(CMD)),)
	@$(BIN)ansible '$(H)' $(HOSTARGS) $(BECOME) -m ansible.builtin.shell -a '$(call squote,$(CMD))'
else
	@conn=$$($(BIN)ansible '$(H)' $(HOSTARGS) -m ansible.builtin.debug \
	  -a 'msg={{ ansible_user | default("") }}|{{ ansible_host | default(inventory_hostname) }}|{{ ansible_port | default(22) }}|{{ ansible_ssh_private_key_file | default("") }}|{{ ansible_ssh_common_args | default("") }}' \
	  | sed -n 's/^.*"msg": "\([^"]*\)".*$$/\1/p'); \
	[ "$$(printf '%s\n' "$$conn" | grep -c .)" = 1 ] || { echo "H must match exactly one host for an interactive session (got: $$(printf '%s\n' "$$conn" | grep -c .))"; exit 1; }; \
	u=$$(echo "$$conn" | cut -d'|' -f1); h=$$(echo "$$conn" | cut -d'|' -f2); p=$$(echo "$$conn" | cut -d'|' -f3); \
	k=$$(echo "$$conn" | cut -d'|' -f4); x=$$(echo "$$conn" | cut -d'|' -f5-); \
	echo ">> ssh to $(H) (exit to leave)"; \
	exec ssh $$x $${k:+-i "$$k"} -p "$$p" "$${u:+$$u@}$$h"
endif

ifeq ($(SHELL_MODE),1)
# shell mode: only `shell` exists; command words become no-op goals (never real targets)
$(SHELL_ARGS):
	@:
else

help: ## Show targets
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z_-]+:.*## /{printf "  \033[36m%-12s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo "  vars: ENV=$(ENV) LIMIT= TAGS= SKIP= EXTRA= PLAY=$(PLAY) H= SUDO=1 FILE= VAULT_IDS= BECOME_ASK=0 (sudo pass: $(or $(BECOME_FILE),none))"

setup: ## Install/upgrade ansible + latest collections (./.venv, ./collections) + agent skills if missing
	@scripts/ensure-toolchain.sh .

skills: ## (Re)install/update the AI agent skills user-wide (needs npx)
	npx -y skills add ahmz1833/server-setup -g -y --skill '*'

validate: ## Check vars against role argument specs — offline, no server contact
	$(BIN)ansible-playbook playbooks/$(PLAY).yml $(ARGS) --tags __argspec_only__ \
	  -e ansible_connection=local -e ansible_become=false \
	  -e 'ansible_python_interpreter={{ ansible_playbook_python }}'

check: ## Dry-run PLAY (default site) with diff
	$(BIN)ansible-playbook playbooks/$(PLAY).yml $(ARGS) --check --diff

apply: ## Apply PLAY (default site) — use LIMIT/TAGS to keep the blast radius small
	$(BIN)ansible-playbook playbooks/$(PLAY).yml $(ARGS)

run: ## Run any playbook: make run PLAY=ops/restart EXTRA="-e service=nginx" LIMIT=web-1
	$(BIN)ansible-playbook playbooks/$(PLAY).yml $(ARGS)

ping: ## Connectivity check (LIMIT to narrow)
	$(BIN)ansible '$(or $(LIMIT),all)' $(HOSTARGS) -m ansible.builtin.ping

host: ## Resolved vars of a host — vault identifiers shown, credentials hidden (SHOW_VAULT=1: all): make host H=web-1
	@test -n "$(H)" || { echo "usage: make host H=<host>"; exit 1; }
	@$(BIN)ansible-inventory -i $(INV) $(VAULT_ARGS) --host $(H) --yaml \
	  $(if $(filter 1,$(SHOW_VAULT)),,| $(TOOLS) mask)

docker-logs: ## Container logs (read-only): make docker-logs H=web-1 C=app [N=200] [SINCE=10m]; no C = list containers
	@test -n "$(H)" || { echo "usage: make docker-logs H=<host> [C=<container>] [N=200] [SINCE=10m]"; exit 1; }
	@$(BIN)ansible '$(H)' $(HOSTARGS) -b -m ansible.builtin.command \
	  -a "$(if $(C),docker logs --tail $(N) $(if $(SINCE),--since $(SINCE) )--timestamps $(C),docker ps -a)"

module: ## Any Ansible module on servers: make module H=<pattern> M=<module> [A='<args>'] [SUDO=0]
	@test -n "$(H)" -a -n "$(M)" || { echo "usage: make module H=<host|group> M=<module> [A='<args>'] [SUDO=0]"; exit 1; }
	@$(BIN)ansible '$(H)' $(HOSTARGS) $(BECOME) -m $(M) $(if $(A),-a '$(call squote,$(A))')

var: ## Templated value of a variable on a host: make var H=web-1 V=nginx_sites (credentials refused)
	@test -n "$(H)" -a -n "$(V)" || { echo "usage: make var H=<host> V=<variable>"; exit 1; }
	@if [ "$(SHOW_VAULT)" != 1 ] && $(TOOLS) is-credential '$(V)'; then \
	  echo "refusing to print $(V): looks like a credential (SHOW_VAULT=1 to override — humans only)"; exit 1; fi
	@$(BIN)ansible '$(H)' $(HOSTARGS) -m ansible.builtin.debug -a 'var=$(V)'

ssh-config: ## Write this project's hosts into ~/.ssh/config (managed block; REPLACE=1 drops old hand-written entries)
	@ANSIBLE_LOAD_CALLBACK_PLUGINS=1 ANSIBLE_STDOUT_CALLBACK=json $(BIN)ansible all $(HOSTARGS) -m ansible.builtin.debug \
	  -a 'msg={{ {"host": ansible_host | default(inventory_hostname), "port": ansible_port | default(22), "user": ansible_user | default(""), "key": ansible_ssh_private_key_file | default(ssh_config_identity_file | default("")), "extra": ssh_config_extra | default({}), "skip": ssh_config_skip | default(false)} | to_json }}' \
	  | $(TOOLS) ssh-config --project '$(PROJECT)' --file '$(SSH_CONFIG)' $(if $(filter 1,$(REPLACE)),--replace)

graph: ## Show groups and hosts
	$(BIN)ansible-inventory -i $(INV) $(VAULT_ARGS) --graph

vault-init: ## Create+encrypt missing vault.yml files of ENV from their *.example
	@if [ -z "$(VAULT_IDS)" ] && [ ! -f $(INIT_FILE) ]; then \
	  umask 077; openssl rand -base64 32 > $(INIT_FILE); \
	  echo ">> generated $(INIT_FILE) — store it in your password manager NOW (gitignored)"; fi
	@find $(INV) -name 'vault.yml.example' | while read ex; do \
	  f="$${ex%.example}"; [ -f "$$f" ] && continue; cp "$$ex" "$$f"; \
	  $(BIN)ansible-vault encrypt --encrypt-vault-id $(firstword $(subst @, ,$(INIT_ID))) \
	    --vault-id $(INIT_ID) "$$f" && echo ">> created $$f  (make vault-edit FILE=$$f)"; done

vault-edit: ## Edit an encrypted file: make vault-edit FILE=<path>
	$(BIN)ansible-vault edit --vault-id $(VAULT_ID) $(FILE)

vault-view: ## View an encrypted file: make vault-view FILE=<path>
	$(BIN)ansible-vault view --vault-id $(VAULT_ID) $(FILE)

vault-keys: ## List the KEYS (never values) of every vault file in ENV
	@for f in $$(find $(INV) -name 'vault.yml' | sort); do \
	  echo "$$f:"; $(BIN)ansible-vault view --vault-id $(VAULT_ID) "$$f" \
	    | awk -F: '/^[A-Za-z_][A-Za-z0-9_]*:/{print "  - "$$1}'; done

vault-gen: ## Add a RANDOM secret without printing it: make vault-gen KEY=vault_x [FILE=…] [LEN=32]
	@test -n "$(KEY)" || { echo "usage: make vault-gen KEY=vault_<name> [FILE=<vault.yml>] [LEN=32]"; exit 1; }
	@if $(BIN)ansible-vault view --vault-id $(VAULT_ID) $(FILE) | grep -q '^$(KEY):'; then \
	  echo "$(KEY) already exists in $(FILE) — not changed"; exit 1; fi
	@{ $(BIN)ansible-vault view --vault-id $(VAULT_ID) $(FILE); \
	   printf '%s: "%s"\n' '$(KEY)' "$$(openssl rand -base64 $(or $(LEN),32) | tr -d '\n/+=' )"; } \
	 | $(BIN)ansible-vault encrypt --vault-id $(VAULT_ID) --encrypt-vault-id $(firstword $(subst @, ,$(VAULT_ID))) \
	     --output $(FILE).new - && mv $(FILE).new $(FILE) && echo ">> added $(KEY) to $(FILE) (value not shown)"

vault-check: ## Fail if any vault*.yml is not encrypted
	@bad=$$(find . -path ./collections -prune -o -path ./.venv -prune -o \
	  -type f -name 'vault*.yml' ! -name '*.example' -print | \
	  while read f; do head -1 "$$f" | grep -q '^\$$ANSIBLE_VAULT' || echo "$$f"; done); \
	if [ -n "$$bad" ]; then echo "NOT ENCRYPTED:"; echo "$$bad"; exit 1; else echo "vault-check: ok"; fi

lint: ## ansible-lint + yamllint
	$(BIN)ansible-lint playbooks $(wildcard roles)
	$(BIN)yamllint -s .

docker-shell: ## No local ansible? Shell in the runner image with this repo mounted
	docker run --rm -it -v "$(CURDIR)":/work -w /work -v "$(HOME)/.ssh":/root/.ssh:ro $(IMAGE) sh

endif

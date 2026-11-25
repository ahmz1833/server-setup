# Infra Makefile — standard from ahmz1833/server-setup (examples/starter).
# Run `make help`. Every playbook target accepts:
#   ENV=<env>  LIMIT=<host|group>  TAGS=<t1,t2>  SKIP=<tags>  EXTRA="<more ansible args>"
# Run any command inside the project toolchain:
#   make shell                          interactive subshell
#   make shell -- ansible all -m ping   one command (words after --)
#   make shell CMD='ansible web -b -a "df -h"'   use CMD when args contain '=' or quotes
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
# BECOME_ASK=1 to be prompted for the sudo password.
BECOME_ASK ?= 0

comma := ,
# `make shell -- <cmd>`: the words after `shell` are the command, not make targets.
ifeq (shell,$(firstword $(MAKECMDGOALS)))
  SHELL_MODE := 1
  SHELL_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
endif
CMD ?= $(SHELL_ARGS)
BIN := $(if $(wildcard .venv/bin/ansible-playbook),.venv/bin/,)
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

ARGS := -i $(INV) $(VAULT_ARGS) \
  $(if $(LIMIT),--limit '$(LIMIT)') $(if $(TAGS),--tags '$(TAGS)') \
  $(if $(SKIP),--skip-tags '$(SKIP)') $(if $(filter 1,$(BECOME_ASK)),--ask-become-pass) $(EXTRA)

.PHONY: help setup skills shell validate check apply run ping host docker-logs graph vault-init vault-edit vault-view vault-keys vault-gen vault-check lint docker-shell

shell: ## Toolchain shell: `make shell`, `make shell -- <cmd>`, or CMD='<cmd>'
	@$(if $(CMD),,echo ">> infra shell: ENV=$(ENV) inventory=$(INV) vault=$(if $(VAULT_ARGS),$(VAULT_ID),none) (exit to leave)")
	@env PATH="$(if $(BIN),$(CURDIR)/.venv/bin:)$$PATH" \
	  ANSIBLE_INVENTORY="$(CURDIR)/$(INV)" \
	  ANSIBLE_VAULT_IDENTITY_LIST="$(if $(strip $(VAULT_IDS)),$(subst $(eval) ,$(comma),$(strip $(VAULT_IDS))),$(if $(VAULT_ARGS),$(VAULT_ID)))" \
	  INFRA_ENV="$(ENV)" $(if $(CMD),sh -c '$(subst ','\'',$(CMD))',$${SHELL:-bash})

ifeq ($(SHELL_MODE),1)
# shell mode: only `shell` exists; command words become no-op goals (never real targets)
$(SHELL_ARGS):
	@:
else

help: ## Show targets
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z_-]+:.*## /{printf "  \033[36m%-12s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo "  vars: ENV=$(ENV) LIMIT= TAGS= SKIP= EXTRA= PLAY=$(PLAY) H= FILE= VAULT_IDS="

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
	$(BIN)ansible $(or $(LIMIT),all) -i $(INV) $(VAULT_ARGS) -m ansible.builtin.ping

host: ## Resolved vars of a host (vault_* values hidden; SHOW_VAULT=1 shows them): make host H=web-1
	@test -n "$(H)" || { echo "usage: make host H=<host>"; exit 1; }
	@$(BIN)ansible-inventory -i $(INV) $(VAULT_ARGS) --host $(H) --yaml \
	  $(if $(filter 1,$(SHOW_VAULT)),,| awk '/^vault_/{split($$0,k,":"); print k[1]": <hidden>"; skip=1; next} /^[^ ]/{skip=0} !skip')

docker-logs: ## Container logs (read-only): make docker-logs H=web-1 C=app [N=200] [SINCE=10m]; no C = list containers
	@test -n "$(H)" || { echo "usage: make docker-logs H=<host> [C=<container>] [N=200] [SINCE=10m]"; exit 1; }
	@$(BIN)ansible $(H) -i $(INV) $(VAULT_ARGS) -b -m ansible.builtin.command \
	  -a "$(if $(C),docker logs --tail $(N) $(if $(SINCE),--since $(SINCE) )--timestamps $(C),docker ps -a)"

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

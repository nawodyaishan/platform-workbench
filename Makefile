# Thin facade over Taskfile.yml for people who reach for `make`. It holds no logic of its
# own: every target forwards to the matching `task`, so there is one source of truth.
# Works with the macOS system make (3.81). Variables: HOST=<alias> PROFILE=<name> ARGS="--dry-run".

TASK ?= task
HOST ?=
PROFILE ?=
KEY ?=
TOPIC ?=
ARGS ?=
DISTRO ?=
METHOD ?=

# Only pass a variable through when it is set, so `requires:` checks in the Taskfile still fire.
VARS = $(if $(HOST),HOST=$(HOST)) $(if $(PROFILE),PROFILE=$(PROFILE)) $(if $(KEY),KEY=$(KEY))
ARGS_SUFFIX = $(if $(ARGS),-- $(ARGS))

.DEFAULT_GOAL := help
.PHONY: help preflight install-task install-aliases install-ubuntu install-rhel install-proxmox devstack devstack-update devstack-verify bootstrap update verify verify-all main ssh rhel ubuntu proxmox hosts \
        ssh-copy-id gh-key aliases kk lint secrets repo check test-remote test-profiles hooks

help: ## Show this help (works without Task installed)
	@echo "platform-workbench (make is a thin wrapper around task)"
	@echo "Usage: make <target> [HOST=alias] [PROFILE=name] [TOPIC=name] [ARGS=\"--dry-run\"]"
	@echo ""
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z0-9_ -]+:.*## /{printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Fresh Linux host (Ubuntu, RHEL, Proxmox), logged in as root or a sudo user:"
	@echo "  make install-task            # installs Task, no sudo needed as root"
	@echo "  make install-aliases         # aliases only"
	@echo "  make install-proxmox ARGS=--dry-run   # Task + full profile; drop ARGS to apply"
	@echo "Everything else: $(TASK) --list"

preflight:
	@command -v $(TASK) >/dev/null 2>&1 || { echo "task not found: install Task first (brew install go-task, https://taskfile.dev)" >&2; exit 127; }

bootstrap: preflight ## Install and wire a profile locally, or on HOST
	@$(TASK) bootstrap $(VARS) $(ARGS_SUFFIX)
update: preflight ## Upgrade profile-managed packages and refresh config
	@$(TASK) update $(VARS) $(ARGS_SUFFIX)
verify: preflight ## Read-only health check (exit 1 on drift)
	@$(TASK) verify $(VARS) $(ARGS_SUFFIX)
verify-all: preflight ## Verify the Mac and every registered host
	@$(TASK) verify:all

main: preflight ## Attach to (or create) local tmux session "main"
	@$(TASK) main
ssh: preflight ## SSH to HOST and attach its tmux "main"
	@$(TASK) ssh $(VARS)
rhel ubuntu proxmox: preflight ## Session on that lab host
	@$(TASK) $@

hosts: preflight ## List registered hosts (read-only)
	@$(TASK) hosts
ssh-copy-id: preflight ## Install a PUBLIC key on HOST
	@$(TASK) ssh:copy-id $(VARS)
gh-key: preflight ## Create a distinct GitHub key on HOST
	@$(TASK) gh-key $(VARS)
aliases: preflight ## Copy the paste-in aliases installer
	@$(TASK) aliases
kk: preflight ## Copy a KodeKloud snippet to the clipboard (TOPIC=cka|k8s|terraform|aws|ansible|linux)
	@$(TASK) kk $(if $(TOPIC),TOPIC=$(TOPIC))

lint: preflight ## Syntax-check scripts and validate configs
	@$(TASK) lint
secrets: preflight ## Scan for credentials and private infrastructure details
	@$(TASK) secrets
repo: preflight ## Check structure, host registry and Markdown links
	@$(TASK) repo
check: preflight ## lint + secrets + repo
	@$(TASK) check
test-remote: preflight ## Offline remote-flow tests
	@$(TASK) test:remote
test-profiles: preflight ## Container smoke tests (ARGS="rhel ubuntu proxmox")
	@$(TASK) test:profiles $(ARGS_SUFFIX)
hooks: preflight ## Install the pre-commit hook
	@$(TASK) hooks

# Install flow for Linux hosts. install-task runs the script directly because Task does not
# exist yet; as root it never calls sudo. Pass the Task flags with ARGS="--dry-run".
install-task: ## Install Task on this Linux host (auto-detects Ubuntu/RHEL/Proxmox)
	@./scripts/install-task.sh $(if $(DISTRO),--distro $(DISTRO)) $(if $(METHOD),--method $(METHOD))
install-aliases: ## Install only the aliases and functions into this user's rc file
	@./scripts/aliases-snippet.sh | bash
install-ubuntu: install-task ## Task + ubuntu profile on this host
	@$(TASK) install:ubuntu $(ARGS_SUFFIX)
install-rhel: install-task ## Task + rhel profile on this host
	@$(TASK) install:rhel $(ARGS_SUFFIX)
install-proxmox: install-task ## Task + minimal proxmox profile on this host (run as root)
	@$(TASK) install:proxmox $(ARGS_SUFFIX)
devstack: preflight ## Full-stack dev toolchain on this Ubuntu host (ARGS=--dry-run first)
	@$(TASK) devstack $(ARGS_SUFFIX)
devstack-update: preflight ## Upgrade the dev toolchain on this Ubuntu host
	@$(TASK) devstack:update $(ARGS_SUFFIX)
devstack-verify: preflight ## Read-only check of the dev toolchain
	@$(TASK) devstack:verify $(ARGS_SUFFIX)

# Thin facade over Taskfile.yml for people who reach for `make`. It holds no logic of its
# own: every target forwards to the matching `task`, so there is one source of truth.
# Works with the macOS system make (3.81). Variables: HOST=<alias> PROFILE=<name> ARGS="--dry-run".

TASK ?= task
HOST ?=
PROFILE ?=
KEY ?=
TOPIC ?=
ARGS ?=

# Only pass a variable through when it is set, so `requires:` checks in the Taskfile still fire.
VARS = $(if $(HOST),HOST=$(HOST)) $(if $(PROFILE),PROFILE=$(PROFILE)) $(if $(KEY),KEY=$(KEY))
ARGS_SUFFIX = $(if $(ARGS),-- $(ARGS))

.DEFAULT_GOAL := help
.PHONY: help preflight bootstrap update verify verify-all main ssh rhel ubuntu proxmox hosts \
        ssh-copy-id gh-key aliases kk lint secrets repo check test-remote test-profiles hooks

help: preflight ## Show workbench commands
	@echo "platform-workbench (make is a thin wrapper around task)"
	@echo "  lifecycle  make bootstrap|update|verify [HOST=alias | PROFILE=macos|rhel|ubuntu|proxmox] [ARGS=\"--dry-run\"]"
	@echo "             make verify-all"
	@echo "  sessions   make main | make ssh HOST=alias | make rhel | make ubuntu | make proxmox"
	@echo "  hosts      make hosts | make ssh-copy-id HOST=alias [KEY=~/.ssh/id_ed25519.pub] | make gh-key HOST=alias"
	@echo "  shell      make aliases | make kk [TOPIC=cka|k8s|terraform|aws|ansible|linux]"
	@echo "  repo       make lint | secrets | repo | check | test-remote | test-profiles | hooks"
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

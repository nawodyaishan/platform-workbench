# Thin facade over Taskfile.yml for people who reach for `make`. It holds no logic of its
# own: every target forwards to the matching `task`, so there is one source of truth.
# Works with the macOS system make (3.81). The command reference, `make help`, comes from
# scripts/help.sh, the same table `task help` prints, so target descriptions live there.

TASK ?= task
HOST ?=
PROFILE ?=
KEY ?=
TOPIC ?=
ARGS ?=
DISTRO ?=
METHOD ?=
CMD ?=

# Only pass a variable through when it is set, so `requires:` checks in the Taskfile still fire.
VARS = $(if $(HOST),HOST=$(HOST)) $(if $(PROFILE),PROFILE=$(PROFILE)) $(if $(KEY),KEY=$(KEY))
ARGS_SUFFIX = $(if $(ARGS),-- $(ARGS))

.DEFAULT_GOAL := help
.PHONY: help preflight install-task install-aliases install-ubuntu install-rhel install-proxmox devstack devstack-update devstack-verify bootstrap update verify verify-all main ssh rhel ubuntu proxmox hosts \
        ssh-copy-id gh-key aliases kk lint secrets repo check test-remote test-profiles hooks

# make help [CMD=target]: works before Task is installed.
help:
	@bash ./scripts/help.sh --make $(CMD)

preflight:
	@command -v $(TASK) >/dev/null 2>&1 || { echo "task not found: install Task first (brew install go-task, https://taskfile.dev)" >&2; exit 127; }

bootstrap: preflight
	@$(TASK) bootstrap $(VARS) $(ARGS_SUFFIX)
update: preflight
	@$(TASK) update $(VARS) $(ARGS_SUFFIX)
verify: preflight
	@$(TASK) verify $(VARS) $(ARGS_SUFFIX)
verify-all: preflight
	@$(TASK) verify:all

main: preflight
	@$(TASK) main
ssh: preflight
	@$(TASK) ssh $(VARS)
rhel ubuntu proxmox: preflight
	@$(TASK) $@

hosts: preflight
	@$(TASK) hosts
ssh-copy-id: preflight
	@$(TASK) ssh:copy-id $(VARS)
gh-key: preflight
	@$(TASK) gh-key $(VARS)
aliases: preflight
	@$(TASK) aliases
kk: preflight
	@$(TASK) kk $(if $(TOPIC),TOPIC=$(TOPIC))

lint: preflight
	@$(TASK) lint
secrets: preflight
	@$(TASK) secrets
repo: preflight
	@$(TASK) repo
check: preflight
	@$(TASK) check
test-remote: preflight
	@$(TASK) test:remote
test-profiles: preflight
	@$(TASK) test:profiles $(ARGS_SUFFIX)
hooks: preflight
	@$(TASK) hooks

# Install flow for Linux hosts. install-task runs the script directly because Task does not
# exist yet; as root it never calls sudo. Pass the Task flags with ARGS="--dry-run".
install-task:
	@./scripts/install-task.sh $(if $(DISTRO),--distro $(DISTRO)) $(if $(METHOD),--method $(METHOD))
install-aliases:
	@./scripts/aliases-snippet.sh | bash
install-ubuntu: install-task
	@$(TASK) install:ubuntu $(ARGS_SUFFIX)
install-rhel: install-task
	@$(TASK) install:rhel $(ARGS_SUFFIX)
install-proxmox: install-task
	@$(TASK) install:proxmox $(ARGS_SUFFIX)
devstack: preflight
	@$(TASK) devstack $(ARGS_SUFFIX)
devstack-update: preflight
	@$(TASK) devstack:update $(ARGS_SUFFIX)
devstack-verify: preflight
	@$(TASK) devstack:verify $(ARGS_SUFFIX)

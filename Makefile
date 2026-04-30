SHELL := /usr/bin/env bash

.PHONY: help check-tools doctor \
	up status ssh vm-info provision bringup rebuild halt destroy clean \
	up-all halt-all status-all ssh-all provision-all destroy-all vm-info-all

# Supported model: run make from WSL and drive Hyper-V Vagrant via Windows PowerShell.
VAGRANT_PS := powershell.exe -NoProfile -Command
PROVIDER ?= hyperv
ROOT_DIR_WIN := $(shell wslpath -w "$(CURDIR)")

# Friendly aliases used in targets (up-hub, up-docker, up-base)
VM_ALIASES := base docker hub
VM_NAME_base := base-server-01
VM_NAME_docker := docker-server-01
VM_NAME_hub := hub-01

define assert_windows_interop
	if ! command -v cmd.exe >/dev/null 2>&1; then \
		echo "ERROR: cmd.exe not found from WSL."; \
		echo "Fix WSL Windows interop, then retry."; \
		exit 1; \
	fi; \
	if ! cmd.exe /c ver >/dev/null 2>&1; then \
		echo "ERROR: Windows interop is broken in this WSL session (Exec format error)."; \
		echo "Run Vagrant targets from Windows host shell, or repair WSL interop and retry."; \
		exit 1; \
	fi
endef

help:
	@echo "Available targets:"
	@echo "  help         - Show this help text"
	@echo "  check-tools  - Validate Windows Vagrant availability from WSL"
	@echo "  doctor       - Diagnose WSL Windows interop and tools availability"
	@echo "  up-<vm>      - Start one VM (vm: base|docker|hub)"
	@echo "  halt-<vm>    - Halt one VM"
	@echo "  status-<vm>  - Status for one VM"
	@echo "  ssh-<vm>     - SSH one VM (optional: CMD='<command>')"
	@echo "  vm-info-<vm> - Run /vagrant/scripts/vm-info.sh in one VM"
	@echo "  provision-<vm> - Run 'vagrant provision' for one VM"
	@echo "  destroy-<vm> - Destroy one VM"
	@echo "  up-all       - Start all VMs"
	@echo "  halt-all     - Halt all VMs"
	@echo "  status-all   - Status for all VMs"
	@echo "  ssh-all      - SSH command on all VMs (requires CMD='<command>')"
	@echo "  provision-all - Provision all VMs"
	@echo "  destroy-all  - Destroy all VMs"
	@echo "  bringup      - check-tools -> up-all"
	@echo "  rebuild      - destroy-all -> up-all"
	@echo "  up/status/ssh/vm-info/provision/halt/destroy map to hub"
	@echo "  clean        - No-op placeholder"

doctor:
	@echo "=== WSL Windows interop ==="; \
	if ! command -v cmd.exe >/dev/null 2>&1; then \
		echo "FAIL  cmd.exe not found in PATH"; \
		echo "      /proc/sys/fs/binfmt_misc may not have a PE handler registered."; \
	else \
		echo "OK    cmd.exe found: $$(command -v cmd.exe)"; \
		if cmd.exe /c ver >/dev/null 2>&1; then \
			echo "OK    Windows interop is functional"; \
		else \
			echo "FAIL  cmd.exe present but cannot be executed (Exec format error)"; \
			echo ""; \
			echo "      Root causes:"; \
			echo "        1. Interop disabled for this process tree (most common)."; \
			echo "           Tools like Docker Desktop or VS Code Remote-WSL call"; \
			echo "           prctl(PR_SET_NO_NEW_PRIVS) on startup, which disables"; \
			echo "           WSL interop for all child processes of that session."; \
			echo "        2. interop.enabled=false set in /etc/wsl.conf."; \
			echo "        3. WSL interop disabled globally via /proc/sys/fs/interop."; \
			echo ""; \
			echo "      Fixes to try (in order):"; \
			echo "        a. Open a new WSL terminal directly from Windows"; \
			echo "           (Start menu, Windows Terminal, or wsl.exe in cmd/PS)."; \
			echo "           Do NOT launch it from inside VS Code or Docker."; \
			echo "        b. Check /etc/wsl.conf for 'enabled=false' under [interop]."; \
			echo "           Remove or set 'enabled=true', then restart WSL."; \
			echo "        c. Restart WSL entirely: run 'wsl --shutdown' from Windows,"; \
			echo "           then reopen your WSL terminal."; \
			echo "        d. Check: cat /proc/sys/fs/binfmt_misc/WSLInterop"; \
			echo "           If it shows 'disabled', run:"; \
			echo "           echo 1 | sudo tee /proc/sys/fs/binfmt_misc/WSLInterop"; \
			echo "           (only persists until next WSL shutdown)"; \
			echo ""; \
			echo "      Vagrant and all Windows-host targets require working interop."; \
		fi; \
	fi; \
	echo ""; \
	echo "=== WSL interop configuration ==="; \
	if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then \
		echo "      /proc/sys/fs/binfmt_misc/WSLInterop:"; \
		cat /proc/sys/fs/binfmt_misc/WSLInterop 2>/dev/null | head -n3 | sed 's/^/        /'; \
	else \
		echo "      WSLInterop binfmt entry not found"; \
	fi; \
	if [ -f /etc/wsl.conf ]; then \
		echo "      /etc/wsl.conf:"; \
		cat /etc/wsl.conf | sed 's/^/        /'; \
	else \
		echo "      /etc/wsl.conf not present (interop defaults to enabled)"; \
	fi; \
	echo ""; \
	echo "=== Windows-side tools (requires working interop) ==="; \
	if command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c ver >/dev/null 2>&1; then \
		if command -v powershell.exe >/dev/null 2>&1; then \
			ps_ver=$$(powershell.exe -NoProfile -Command "$$PSVersionTable.PSVersion" 2>/dev/null); \
			echo "OK    powershell.exe: $$ps_ver"; \
		else \
			echo "MISS  powershell.exe not found"; \
		fi; \
		if $(VAGRANT_PS) "Get-Command vagrant -ErrorAction SilentlyContinue" >/dev/null 2>&1; then \
			vag_ver=$$($(VAGRANT_PS) "vagrant --version" 2>/dev/null); \
			echo "OK    vagrant (Windows): $$vag_ver"; \
		else \
			echo "MISS  vagrant not found on Windows host"; \
			echo "      Install from https://developer.hashicorp.com/vagrant/install"; \
		fi; \
	else \
		echo "SKIP  Cannot check Windows tools (interop not working)"; \
	fi

check-tools:
	@set -euo pipefail; \
	$(assert_windows_interop); \
	if ! command -v powershell.exe >/dev/null 2>&1; then \
		echo "ERROR: powershell.exe not reachable from WSL"; \
		exit 1; \
	fi; \
	$(VAGRANT_PS) "if (-not (Get-Command vagrant -ErrorAction SilentlyContinue)) { Write-Host 'ERROR: Windows vagrant not found'; exit 1 }"; \
	echo "Tools check passed."

define vm_dir
$(ROOT_DIR_WIN)\vms\$(VM_NAME_$(1))
endef

define run_vagrant
	@set -euo pipefail; \
	$(assert_windows_interop); \
	$(VAGRANT_PS) "Set-Location '$(call vm_dir,$(1))'; vagrant $(2)"
endef

# Validate that target alias exists in VM_ALIASES.
define assert_valid_alias
	@if [ -z "$(VM_NAME_$*)" ]; then \
		echo "ERROR: unknown VM alias '$*'. Allowed: $(VM_ALIASES)"; \
		exit 1; \
	fi
endef

up-%:
	$(assert_valid_alias)
	$(call run_vagrant,$*,up --provider=$(PROVIDER))

status-%:
	$(assert_valid_alias)
	$(call run_vagrant,$*,status)

halt-%:
	$(assert_valid_alias)
	$(call run_vagrant,$*,halt)

destroy-%:
	$(assert_valid_alias)
	$(call run_vagrant,$*,destroy -f)

provision-%:
	$(assert_valid_alias)
	$(call run_vagrant,$*,provision)

vm-info-%:
	$(assert_valid_alias)
	$(call run_vagrant,$*,ssh -c "bash /vagrant/scripts/vm-info.sh")

ssh-%:
	$(assert_valid_alias)
	@if [ -n "$(CMD)" ]; then \
		$(call run_vagrant,$*,ssh -c "$(CMD)"); \
	else \
		$(call run_vagrant,$*,ssh); \
	fi

up-all: $(addprefix up-,$(VM_ALIASES))

status-all: $(addprefix status-,$(VM_ALIASES))

halt-all: $(addprefix halt-,$(VM_ALIASES))

provision-all: $(addprefix provision-,$(VM_ALIASES))

destroy-all: $(addprefix destroy-,$(VM_ALIASES))

ssh-all:
	@set -euo pipefail; \
	if [ -z "$(CMD)" ]; then \
		echo "ERROR: ssh-all requires CMD='<command>'"; \
		exit 1; \
	fi; \
	for vm in $(VM_ALIASES); do \
		$(MAKE) --no-print-directory ssh-$$vm CMD="$(CMD)"; \
	done

vm-info-all: $(addprefix vm-info-,$(VM_ALIASES))

clean:
	@echo "Nothing to clean."

SERVER_IP ?= 192.168.1.138

verify-dns:
	@echo "Checking if Windows hosts file is blocking hub.local..."
	@grep "hub.local" /mnt/c/Windows/System32/drivers/etc/hosts || echo "Clear!"
	@echo "Testing Pi-hole resolution on $(SERVER_IP)..."
	@dig @$(SERVER_IP) anything.hub.local +short
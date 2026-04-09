SHELL := /usr/bin/env bash

.PHONY: help check-tools doctor up status ssh inventory verify provision bringup rebuild halt destroy clean

# Supported model: run make from WSL, drive Hyper-V Vagrant via Windows PowerShell,
# and run Ansible from WSL using inventory generated from live Vagrant ssh-config.
VAGRANT_PS := powershell.exe -NoProfile -Command
UBUNTU_VM_DIR_WIN := d:\vm-home\vms\ubuntu
VM_NAME ?= ubuntu
INVENTORY_DIR := ansible/inventory/generated
INVENTORY_FILE := $(INVENTORY_DIR)/$(VM_NAME).yml
PING_HOST_PATTERN ?= all
PLAYBOOK ?= ansible/playbooks/ping.yml

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
	@echo "  check-tools  - Validate WSL Ansible and Windows Vagrant availability"
	@echo "  doctor       - Diagnose WSL Windows interop and tools availability"
	@echo "  up           - Start VM using Hyper-V provider"
	@echo "  status       - Show VM status"
	@echo "  ssh          - SSH into VM (optional: CMD='<command>')"
	@echo "  inventory    - Generate runtime Ansible inventory from vagrant ssh-config"
	@echo "  verify       - Run ansible ping against generated inventory"
	@echo "  provision    - Run playbook against generated inventory"
	@echo "  bringup      - check-tools -> up -> inventory -> verify"
	@echo "  rebuild      - destroy -> up -> inventory -> verify"
	@echo "  halt         - Gracefully stop VM"
	@echo "  destroy      - Destroy VM"
	@echo "  clean        - Remove generated inventory artifacts"

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
	echo "=== WSL-side tools ==="; \
	for tool in ansible ansible-playbook; do \
		if command -v $$tool >/dev/null 2>&1; then \
			echo "OK    $$tool: $$($$tool --version 2>&1 | head -n1)"; \
		else \
			echo "MISS  $$tool not found in WSL PATH"; \
		fi; \
	done; \
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
	if ! command -v ansible >/dev/null 2>&1; then \
		echo "ERROR: ansible not found in WSL PATH"; \
		exit 1; \
	fi; \
	if ! command -v ansible-playbook >/dev/null 2>&1; then \
		echo "ERROR: ansible-playbook not found in WSL PATH"; \
		exit 1; \
	fi; \
	$(assert_windows_interop); \
	if ! command -v powershell.exe >/dev/null 2>&1; then \
		echo "ERROR: powershell.exe not reachable from WSL"; \
		exit 1; \
	fi; \
	$(VAGRANT_PS) "if (-not (Get-Command vagrant -ErrorAction SilentlyContinue)) { Write-Host 'ERROR: Windows vagrant not found'; exit 1 }"; \
	echo "Tools check passed."

up:
	@set -euo pipefail; \
	$(assert_windows_interop); \
	$(VAGRANT_PS) "Set-Location '$(UBUNTU_VM_DIR_WIN)'; vagrant up --provider=hyperv"

status:
	@set -euo pipefail; \
	$(assert_windows_interop); \
	$(VAGRANT_PS) "Set-Location '$(UBUNTU_VM_DIR_WIN)'; vagrant status"

ssh:
	@set -euo pipefail; \
	$(assert_windows_interop); \
	if [ -n "$(CMD)" ]; then \
		$(VAGRANT_PS) "Set-Location '$(UBUNTU_VM_DIR_WIN)'; vagrant ssh -c \"$(CMD)\""; \
	else \
		$(VAGRANT_PS) "Set-Location '$(UBUNTU_VM_DIR_WIN)'; vagrant ssh"; \
	fi

inventory:
	@set -euo pipefail; \
	$(assert_windows_interop); \
	mkdir -p "$(INVENTORY_DIR)"; \
	ssh_cfg_file="$$(mktemp)"; \
	$(VAGRANT_PS) "Set-Location '$(UBUNTU_VM_DIR_WIN)'; vagrant ssh-config" > "$$ssh_cfg_file"; \
	host_name="$$(awk '$$1=="HostName" {print $$2}' "$$ssh_cfg_file" | head -n1)"; \
	port="$$(awk '$$1=="Port" {print $$2}' "$$ssh_cfg_file" | head -n1)"; \
	user="$$(awk '$$1=="User" {print $$2}' "$$ssh_cfg_file" | head -n1)"; \
	identity_file="$$(awk '$$1=="IdentityFile" {print $$2}' "$$ssh_cfg_file" | head -n1)"; \
	rm -f "$$ssh_cfg_file"; \
	if [ -z "$$host_name" ] || [ -z "$$port" ] || [ -z "$$user" ] || [ -z "$$identity_file" ]; then \
		echo "ERROR: could not parse vagrant ssh-config. Is the VM running?"; \
		exit 1; \
	fi; \
	identity_file="$${identity_file//\\\\//}"; \
	if [[ "$$identity_file" =~ ^([A-Za-z]):/(.*)$$ ]]; then \
		drive="$${BASH_REMATCH[1],,}"; \
		rest="$${BASH_REMATCH[2]}"; \
		identity_file="/mnt/$$drive/$$rest"; \
	fi; \
	printf '%s\n' \
		'all:' \
		'  hosts:' \
		'    $(VM_NAME):' \
		"      ansible_host: $$host_name" \
		"      ansible_port: $$port" \
		"      ansible_user: $$user" \
		"      ansible_ssh_private_key_file: $$identity_file" \
		'  vars:' \
		'    ansible_connection: ssh' \
		> "$(INVENTORY_FILE)"
	@echo "Generated inventory: $(INVENTORY_FILE)"

verify: inventory
	ansible -i "$(INVENTORY_FILE)" "$(PING_HOST_PATTERN)" -m ansible.builtin.ping

provision: inventory
	ansible-playbook -i "$(INVENTORY_FILE)" "$(PLAYBOOK)"

bringup: check-tools up inventory verify

rebuild: destroy up inventory verify

halt:
	@set -euo pipefail; \
	$(assert_windows_interop); \
	$(VAGRANT_PS) "Set-Location '$(UBUNTU_VM_DIR_WIN)'; vagrant halt"

destroy:
	@set -euo pipefail; \
	$(assert_windows_interop); \
	$(VAGRANT_PS) "Set-Location '$(UBUNTU_VM_DIR_WIN)'; vagrant destroy -f"

clean:
	rm -f "$(INVENTORY_FILE)"

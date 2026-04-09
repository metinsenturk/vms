SHELL := /usr/bin/env bash

.PHONY: help check-tools up status ssh inventory verify provision bringup rebuild halt destroy clean

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

.PHONY: check-tools up-ubuntu down-ubuntu destroy-ubuntu gitignore

# Vagrant + Hyper-V requires the Windows-native Vagrant to be installed.
# WSL Vagrant cannot drive the Hyper-V provider because its PowerShell scripts
# resolve to \\wsl.localhost\ paths, which Windows PowerShell cannot access.
#
# Install Windows Vagrant: https://developer.hashicorp.com/vagrant/install
# Then verify: powershell.exe -Command "vagrant --version"
#
# All vagrant targets below call powershell.exe so the Windows Vagrant binary
# handles Hyper-V, while Ansible targets continue to run from WSL.

VAGRANT_PS := powershell.exe -NoProfile -Command

# Verify required CLI tools are available
check-tools:
	@echo "Checking required tools..."
	@command -v ansible >/dev/null 2>&1 && echo "✓ ansible found" || echo "✗ ansible NOT found"
	@command -v ansible-playbook >/dev/null 2>&1 && echo "✓ ansible-playbook found" || echo "✗ ansible-playbook NOT found"
	@$(VAGRANT_PS) "Get-Command vagrant -ErrorAction SilentlyContinue | ForEach-Object { Write-Host '✓ vagrant (Windows) found:' $$_.Source } ; if (-not (Get-Command vagrant -ErrorAction SilentlyContinue)) { Write-Host '✗ vagrant (Windows) NOT found — install from https://developer.hashicorp.com/vagrant/install' }"

# Start Ubuntu VM using Hyper-V provider
up-ubuntu:
	$(VAGRANT_PS) "Set-Location 'd:\vm-home\vms\ubuntu'; vagrant up --provider=hyperv"

# Gracefully shut down Ubuntu VM (state preserved)
down-ubuntu:
	$(VAGRANT_PS) "Set-Location 'd:\vm-home\vms\ubuntu'; vagrant halt"

# Destroy Ubuntu VM and remove all associated resources
destroy-ubuntu:
	$(VAGRANT_PS) "Set-Location 'd:\vm-home\vms\ubuntu'; vagrant destroy -f"

# Download Python .gitignore from GitHub
gitignore:
	@if [ -f .gitignore ]; then \
		echo "⚠️  .gitignore already exists, skipping"; \
	else \
		( \
			echo "📥 Downloading Python .gitignore from GitHub..."; \
			curl -fsSL https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore -o .gitignore; \
			echo "✅ .gitignore created"; \
		) > /tmp/gitignore.log 2>&1; \
		echo "✓ .gitignore download complete (log: /tmp/gitignore.log)"; \
	fi

---
name: "My Virtual Machines"
description: "Guidance for working across the WSL-Windows boundary in the VM automation lab."
applyTo: "**"
---

## `INSTRUCTIONS.md`

### 🏗️ Project Architecture: My VMs
This project uses a **Host-First Vagrant** architecture to setup VM environments. 
* **Windows Host:** Manages Hardware (Hyper-V, VM state, Virtual Switches).
* **WSL (Ubuntu):** Manages orchestration logic, Git, and SSH access.

---

### 🛠️ Prerequisites
1. **VS Code** launched as **Administrator** (Required for Hyper-V interop).
2. **Vagrant** installed on Windows Host.
3. **Virtual Switch:** A Hyper-V switch configured for external connectivity (e.g., "External Virtual Switch").
4. **WSL (Ubuntu)** with `ssh`.

---

### 🚀 AI Interaction Guidelines
**Planning Phase (Mandatory):**
Before making any code changes or performing tasks, the AI must:
1.  Analyze the request against the provided context.
2.  Propose a step-by-step plan of action.
3.  Wait for the user to review and approve the plan before proceeding.

**No Makefile Reliance:**
**The `Makefile` is strictly for the user.** 
The AI must never suggest `make <target>`. Always provide the raw underlying command.

**Standard Execution Pattern from WSL:**
To drive the Windows-host Vagrant from WSL, use this specific PowerShell wrapper:
```bash
powershell.exe -NoProfile -Command "Set-Location 'D:\vm-home\vms\<vm-folder>'; vagrant <command>"
```

**Provisioning Pattern:**
Provisioning should be handled via `vagrant ssh -c` or direct SSH commands to ensure script execution happens inside the guest context.

**Task System Sync Contract (Mandatory):**
When updating `tasks.ps1` or `tasks-config.ps1`, also update all related files in the same change so docs and wrappers stay consistent.

Required sync rules:
1. If `tasks-config.ps1` VM aliases or metadata change (`$VM_CONFIGS`):
    - Update VM inventory and alias documentation in `README.md`.
    - Update any relevant configuration or behavior notes in `TASKS.md`.
2. If `tasks-config.ps1` recipes change (`$RECIPES`):
    - Update recipe documentation/examples in `README.md`.
    - Update recipe behavior/details in `TASKS.md`.
3. If `tasks.ps1` internals, command flow, flags, help, doctor checks, or execution behavior change:
    - Update `TASKS.md` technical guide sections to match implementation.
    - Update `README.md` usage/help examples if user-facing behavior changed.
4. If invocation contract/path/wrapper assumptions change for `tasks.ps1`:
    - Update `tasks.cmd` so argument pass-through and script targeting stay correct.
5. Do not leave partial updates: when one task-system file changes, verify and sync all impacted companion files before finishing.

---

### 📂 Directory Structure
* `vms/`: Contains the `Vagrantfile` for each environment (e.g., `vms/hub-01`).
* `vms/<name>/scripts/`: Contains guest-side provisioning scripts.
* `Makefile`: The main entry point for all operations.

---

### ⚠️ Critical Guardrails
1. **Do Not Run `vagrant` in WSL:** Always use `make` or call the Windows `vagrant.exe`. Native WSL Vagrant cannot manage Hyper-V and will cause permission errors on `/mnt/`.
2. **Permission Errors:** If you see `Exec format error`, it is likely due to `PR_SET_NO_NEW_PRIVS` (often caused by starting the terminal from inside VS Code). Refer to `briefs/wsl-windows-interop.md`.
3. **Scripting Safety:** Ensure all `.sh` scripts use `set -euo pipefail` per `coding-standards.instructions.md`.

#### Naming & Directory Convention
* **The Index Rule:** All servers must use the [name]-[index] format (e.g., hub-01, srv-01).
* **One Folder, One Identity:** The directory name under `vms/` MUST match the VM's hostname and the Hyper-V display name.
    * *Example:* `vms/hub-01/` contains a VM named `hub-01`.
* **Explicit Definition:** Always use `config.vm.define "name"` and `config.vm.hostname = "name"` to prevent Vagrant from using the default "default" string.
* **Hardcoded Display Name:** The Hyper-V display name must match the folder name to ensure clarity in the Windows UI.

#### Networking & IP Management
* **Public Bridge:** Use the `public_network` setting to ensure the VM is a first-class citizen on your home network.
    ```ruby
    config.vm.network "public_network", bridge: "External Virtual Switch"
    ```
* **Switch Variable**: The bridge name is hardcoded in each Vagrantfile as `"External Virtual Switch"`. Update it directly in the Vagrantfile if your switch name differs.
* **Deterministic MAC Addresses:** To ensure your router's DHCP reservation never breaks, hardcode a MAC address starting with the Hyper-V prefix `00155D`.
    * *Rule:* Use `00155D` + 6 unique hex characters

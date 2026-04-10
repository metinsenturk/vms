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

---

### 📂 Directory Structure
* `vms/`: Contains the `Vagrantfile` for each environment (e.g., `vms/ubuntu`).
* `vms/<name>/scripts/`: Contains guest-side provisioning scripts.
* `Makefile`: The main entry point for all operations.

---

### ⚠️ Critical Guardrails
1. **Do Not Run `vagrant` in WSL:** Always use `make` or call the Windows `vagrant.exe`. Native WSL Vagrant cannot manage Hyper-V and will cause permission errors on `/mnt/`.
2. **Permission Errors:** If you see `Exec format error`, it is likely due to `PR_SET_NO_NEW_PRIVS` (often caused by starting the terminal from inside VS Code). Refer to `briefs/wsl-windows-interop.md`.
3. **Scripting Safety:** Ensure all `.sh` scripts use `set -euo pipefail` per `coding-standards.instructions.md`.

# VM Tasks Migration Guide

## Overview

This repository has migrated from Make (WSL-dependent) to **Windows-native PowerShell** for VM automation.

## Quick Start

### From PowerShell / Windows Terminal:
```powershell
# Start a VM
.\tasks.ps1 up hub

# SSH to a VM  
.\tasks.ps1 ssh hub

# Run command via SSH
.\tasks.ps1 ssh hub "sudo systemctl status docker"

# Check all VM status
.\tasks.ps1 status all

# Start all VMs
.\tasks.ps1 up all
```

### From CMD:
```cmd
REM Use the batch wrapper
.\tasks.cmd up hub
.\tasks.cmd ssh hub "uptime"
.\tasks.cmd halt all
```

## Available Commands

| Command | Description | Examples |
|---------|-------------|----------|
| `up <vm>` | Start VM(s) | `.\tasks.ps1 up hub`<br/>`.\tasks.ps1 up all` |
| `halt <vm>` | Stop VM(s) | `.\tasks.ps1 halt base`<br/>`.\tasks.ps1 halt all` |
| `ssh <vm> [cmd]` | SSH to VM, optionally run command | `.\tasks.ps1 ssh hub`<br/>`.\tasks.ps1 ssh hub "uptime"` |
| `status <vm>` | Show VM status | `.\tasks.ps1 status docker` |
| `provision <vm>` | Run provisioning | `.\tasks.ps1 provision hub` |
| `destroy <vm>` | Destroy VM (with confirmation) | `.\tasks.ps1 destroy base` |
| `help` | Show detailed help | `.\tasks.ps1 help` |
| `check-tools` | Verify prerequisites | `.\tasks.ps1 check-tools` |
| `doctor` | Full diagnostics | `.\tasks.ps1 doctor` |

## VM Aliases

| Alias | Full VM Name | Purpose |
|-------|-------------|---------|
| `hub` | `hub-01` | Main control node |
| `base` | `base-server-01` | Base server template |
| `docker` | `docker-server-01` | Docker host |

## Configuration

All VM configuration (memory, CPUs, switch name, MAC address) is hardcoded in the respective `vms/<name>/Vagrantfile`. Edit the Vagrantfile directly to adjust hardware settings for your host.

To override the Vagrant provider at runtime, set the `PROVIDER` environment variable in your shell before invoking `tasks.ps1` or `make`:

```powershell
$env:PROVIDER = 'hyperv'
```

## Prerequisites

1. **Vagrant** installed on Windows
2. **Hyper-V** enabled (for VM management)
3. **PowerShell 3.0+** (included with Windows)

Check with: `.\tasks.ps1 check-tools`

## Adding New VMs

1. **Create VM directory**: `mkdir vms\new-vm-01`
2. **Add Vagrantfile** in that directory
3. **Update tasks.ps1**: Add entry to `$VM_ALIASES` hashtable:
   ```powershell
   $VM_ALIASES = @{
       'hub' = 'hub-01'
       'base' = 'base-server-01'
       'docker' = 'docker-server-01'
       'new' = 'new-vm-01'      # Add this line
   }
   ```
4. **Test**: `.\tasks.ps1 up new`

## Migration Notes

### What Changed
- **No more WSL dependency** - pure Windows tooling
- **PowerShell instead of Bash** - leverages native Windows capabilities  
- **Simplified workflow** - no more `powershell.exe -Command` wrappers
- **Better error handling** - PowerShell's structured exception handling
- **No .env file** - all configuration is in Vagrantfiles

### What Stayed the Same
- VM directory structure (`vms\<vm-name>\`)
- Environment variable names
- Vagrant commands and workflows
- Hyper-V provider configuration

### Legacy Makefile

The old `Makefile` is preserved but no longer maintained. If you need WSL compatibility:
```bash
# From WSL (legacy approach)
make up-hub
make ssh-hub CMD="uptime"
```

## Troubleshooting

### "Execution Policy" Error
```powershell
# If you see execution policy errors, run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "vagrant command not found"
- Install Vagrant: https://developer.hashicorp.com/vagrant/install
- Ensure it's in your Windows PATH

### VM Directory Not Found
```powershell
# Check VM directories exist:
.\tasks.ps1 doctor

# Expected structure:
# vms\hub-01\Vagrantfile
# vms\base-server-01\Vagrantfile
# vms\docker-server-01\Vagrantfile
```

### Performance Tips

- Use `.\tasks.ps1 up all` to start multiple VMs in sequence
- Adjust `h.memory` in the Vagrantfile to optimize RAM allocation
- Use `.\tasks.ps1 ssh hub "command"` for quick remote commands

## Examples

```powershell
# Development workflow
.\tasks.ps1 up hub                          # Start main VM
.\tasks.ps1 ssh hub "git pull origin main"  # Update code
.\tasks.ps1 provision hub                   # Re-run provisioning

# Infrastructure management  
.\tasks.ps1 up all                          # Start all VMs
.\tasks.ps1 ssh all "sudo apt update"       # Update all systems
.\tasks.ps1 halt all                        # Stop all VMs

# Troubleshooting
.\tasks.ps1 doctor                          # Full diagnostics
.\tasks.ps1 status all                      # Check all VM states
```
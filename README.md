# VM Automation Lab

A Windows-native Hyper-V lab managed with Vagrant. Each VM lives in its own folder under `vms/` with a dedicated `Vagrantfile` and provisioning scripts.

## Structure

```
vms/
  hub-01/               # Main control node
  base-server-01/       # Base server template
  docker-server-01/     # Docker host
  <name>/Vagrantfile    # All hardware config (memory, CPU, switch, MAC) lives here
```

## Prerequisites

1. **Vagrant** installed on Windows — https://developer.hashicorp.com/vagrant/install
2. **Hyper-V** enabled
3. **PowerShell 3.0+** (included with Windows)

Verify your setup:

```powershell
.\tasks.ps1 check-tools
```

## Usage

There are two ways to manage VMs.

### Option 1 — `tasks.ps1` from the repo root (recommended)

`tasks.ps1` lets you control any VM by alias without changing directories.

```powershell
.\tasks.ps1 up hub           # Start the hub-01 VM
.\tasks.ps1 ssh hub          # Open an SSH session
.\tasks.ps1 provision hub    # Re-run provisioning
.\tasks.ps1 status all       # Show status of all VMs
.\tasks.ps1 halt all         # Stop all VMs
.\tasks.ps1 destroy hub      # Destroy a VM (prompts for confirmation)
```

A `tasks.cmd` batch wrapper is also available for Command Prompt:

```cmd
tasks.cmd up hub
tasks.cmd ssh hub "uptime"
tasks.cmd halt all
```

**Available commands:**

| Command | Description |
|---------|-------------|
| `up <vm\|all>` | Start VM(s) |
| `halt <vm\|all>` | Stop VM(s) |
| `ssh <vm> [cmd]` | SSH to VM, optionally run a command |
| `status <vm\|all>` | Show VM status |
| `provision <vm>` | Run provisioning |
| `destroy <vm>` | Destroy VM (with confirmation) |
| `check-tools` | Verify prerequisites |
| `doctor` | Full diagnostics |
| `help` | Show detailed help |

**VM aliases:**

| Alias | VM Name | Purpose |
|-------|---------|---------|
| `hub` | `hub-01` | Main control node |
| `base` | `base-server-01` | Base server template |
| `docker` | `docker-server-01` | Docker host |
| `ubuntu` | `my-ubuntu-box` | Ubuntu sandbox |

### Option 2 — `vagrant` from a VM folder

Navigate into any VM directory and use standard Vagrant commands directly:

```powershell
cd vms\hub-01
vagrant up
vagrant ssh
vagrant provision
vagrant status
vagrant halt
vagrant destroy
```

## Adding a New VM

1. Create the VM directory: `mkdir vms\new-vm-01`
2. Add a `Vagrantfile` inside it.
3. Register an alias in `tasks.ps1` by adding an entry to `$VM_ALIASES`:

```powershell
$VM_ALIASES = @{
    'hub'    = 'hub-01'
    'base'   = 'base-server-01'
    'docker' = 'docker-server-01'
    'ubuntu' = 'my-ubuntu-box'
    'new'    = 'new-vm-01'        # add this line
}
```

4. Test: `.\tasks.ps1 up new`

## Troubleshooting

**Execution policy error:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**`vagrant` not found:** ensure Vagrant is installed and on your Windows `PATH`.

**General diagnostics:**

```powershell
.\tasks.ps1 doctor
```

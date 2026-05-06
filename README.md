# VM Automation Lab

A Windows-native Hyper-V lab managed with Vagrant. Each VM lives in its own folder under `vms/` with a dedicated `Vagrantfile` and provisioning scripts.

> 📖 New to Vagrant? Read the article: [The Magic of Vagrant — Automating My Home Lab with Infrastructure as Code](https://metinsenturk.me/the-magic-of-vagrant-automating-my-home-lab-with-infrastructure-as-code)

## Prerequisites

1. **Vagrant** — install with `winget install HashiCorp.Vagrant`
2. **Hyper-V** enabled
3. **PowerShell 3.0+** (included with Windows)

Verify your setup:

```powershell
.\tasks.ps1 doctor
```

## VM Inventory

| Alias | Folder | Purpose |
|-------|--------|---------|
| `hub` | `vms/hub-01` | Primary Message Hub & DB |
| `docker` | `vms/docker-server-01` | Docker Container Host |
| `base` | `vms/base-server-01` | Base Server Template |
| `openfang` | `vms/openfang-01` | OpenFANG CTF Target |
| `myubuntubox` | `vms/my-ubuntu-box` | Personal Ubuntu VM |

## Usage

There are two ways to manage VMs.

### Option 1 — `tasks.ps1` from the repo root (recommended)

`tasks.ps1` is a task runner with this argument order:

```text
.\tasks.ps1 <target> <action> [extra args]
```

`<target>` is a VM alias from `tasks-config.ps1`.
`<action>` is either a recipe name or a native Vagrant command.

```powershell
.\tasks.ps1 hub up
.\tasks.ps1 hub ssh
.\tasks.ps1 hub provision
.\tasks.ps1 hub status
.\tasks.ps1 hub destroy -f
.\tasks.ps1 docker up --provider hyperv
.\tasks.ps1 hub audit         # recipe from tasks-config.ps1
```

A `tasks.cmd` batch wrapper is also available for Command Prompt:

```cmd
tasks.cmd hub up
tasks.cmd hub ssh -c "uptime"
tasks.cmd docker status
```

Special commands:

```powershell
.\tasks.ps1 help
.\tasks.ps1 doctor
```

Action behavior:

| Type | Behavior |
|------|----------|
| Recipe | Runs the recipe command list from `tasks-config.ps1` with fail-fast behavior |
| Native command | Proxies directly to `vagrant <action> [extra args]` in the target VM folder |

Examples:

| Command | Result |
|---------|-------------|
| `.\tasks.ps1 hub up` | Start `hub-01` |
| `.\tasks.ps1 base halt` | Stop `base-server-01` |
| `.\tasks.ps1 docker ssh` | Open SSH session to `docker-server-01` |
| `.\tasks.ps1 hub ssh -c "uptime"` | Run remote command through Vagrant SSH |
| `.\tasks.ps1 hub status` | Show VM state |
| `.\tasks.ps1 openfang rebuild` | Run recipe (`destroy -f`, then `up`) |

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

## Troubleshooting

**Execution policy error:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**`vagrant` not found:** install with `winget install HashiCorp.Vagrant`, then restart your terminal.

**General diagnostics:**

```powershell
.\tasks.ps1 doctor
```

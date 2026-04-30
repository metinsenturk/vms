# VM Automation Lab

This repository uses a per-VM Vagrant layout under `vms/` with script-based provisioning.

Supported execution model:
- Run `make` from WSL.
- Use Windows-host Vagrant through PowerShell for Hyper-V operations.
- Run script provisioning from inside the guest VM over `vagrant ssh`.

## Structure

- `vms/<name>/Vagrantfile`: VM-specific orchestration. All configuration (memory, CPU, switch name) is hardcoded here.

## Day 1 Quickstart

1. Review `vms/<name>/Vagrantfile` and update hardware values for your host if required.
2. From repository root in WSL, run:

```bash
make bringup
```

3. Run script provisioning:

```bash
make provision
```

4. Useful lifecycle commands:

```bash
make status
make ssh
make halt
make destroy
```

# VM Automation Lab

This repository uses a per-VM Vagrant layout under `vms/` with script-based provisioning.

Supported execution model:
- Run `make` from WSL.
- Use Windows-host Vagrant through PowerShell for Hyper-V operations.
- Run script provisioning from inside the guest VM over `vagrant ssh`.

## Structure

- `vms/<name>/Vagrantfile`: VM-specific orchestration.
- `.env`: shared environment values.
- `vms/<name>/.env`: optional per-VM overrides.

## Day 1 Quickstart

1. Review `.env` and update values for your host if required.
2. Optional: add overrides in `vms/hub-01/.env`.
3. From repository root in WSL, run:

```bash
make bringup
```

4. Run script provisioning:

```bash
make provision
```

5. Useful lifecycle commands:

```bash
make status
make ssh
make halt
make destroy
```

See `docs/runbooks/day-1-bringup.md` for detailed flow.

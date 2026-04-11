# Day 1 Bring-Up

## Goal

Bring up the first Ubuntu VM on Hyper-V and validate guest accessibility and script provisioning.

## Inputs

- VM folder: `vms/hub-01`
- Hostname: `hub-01`
- Hyper-V switch: `External Virtual Switch`

## Steps

1. Confirm `.env` exists at repository root.
2. Optionally add VM-local overrides in `vms/hub-01/.env`.
3. Start and verify from repository root in WSL:

```bash
make bringup
```

4. Run provisioning script:

```bash
make provision
```

5. Re-run commands to confirm repeatability and idempotent behavior.

## Notes

- Hyper-V Vagrant is supported through Windows-host PowerShell.
- WSL is the supported shell for `make` execution.

## Expected Result

- VM reaches running state.
- SSH command execution succeeds through `make ssh`.
- Provision script runs successfully when present.

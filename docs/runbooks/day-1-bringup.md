# Day 1 Bring-Up

## Goal

Bring up the first Ubuntu VM on Hyper-V and verify Ansible connectivity with `ansible.builtin.ping`.

## Inputs

- VM folder: `vms/ubuntu`
- Hostname: `ubuntu`
- Static IP: `192.168.1.190`
- Hyper-V switch: `External Virtual Switch`

## Steps

1. Confirm `.env` exists at repository root.
2. Optionally add VM-local overrides in `vms/ubuntu/.env`.
3. Start VM from `vms/ubuntu`:

```powershell
vagrant up --provider=hyperv
```

4. Validate inventory ping from repo root:

```powershell
ansible -i ansible/inventory/hosts.yml ubuntu -m ping
```

5. Validate playbook ping from repo root:

```powershell
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/ping.yml
```

6. Re-run commands to confirm repeatability and idempotent behavior.

## Expected Result

- VM reaches running state.
- SSH-based Ansible connection succeeds.
- Ping task reports success on repeated runs.

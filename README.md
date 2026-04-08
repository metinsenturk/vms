# VM Automation Lab

This repository uses a per-VM Vagrant layout under `vms/` and shared provisioning assets under `ansible/`.

## Structure

- `vms/<name>/Vagrantfile`: VM-specific orchestration.
- `.env`: shared environment values.
- `vms/<name>/.env`: optional per-VM overrides.
- `ansible/`: centralized inventory and playbooks.

## Day 1 Quickstart

1. Review `.env` and update values for your host if required.
2. Optional: add overrides in `vms/ubuntu/.env`.
3. From `vms/ubuntu/`, run:

```powershell
vagrant up --provider=hyperv
```

4. From repository root, validate connectivity:

```powershell
ansible -i ansible/inventory/hosts.yml ubuntu -m ping
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/ping.yml
```

See `docs/runbooks/day-1-bringup.md` for detailed flow.

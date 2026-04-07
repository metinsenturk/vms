---
description: "Use when working on VM lifecycle automation with Vagrant, Hyper-V, Ansible, PowerShell, Bash, WinRM, SSH, static lab networking, and provisioning workflows."
name: "VM Automation Standards"
applyTo:
  - "Vagrantfile"
  - "**/*.yml"
  - "**/*.yaml"
  - "**/*.ps1"
  - "**/*.sh"
---

# VM Automation Project Instructions

## Project Scope

- Build and maintain VM automation using Vagrant with the Hyper-V provider.
- Target mixed guest environments: Linux (Ubuntu or Debian) and Windows.
- Prefer Git-friendly, modular automation artifacts that are easy to review and reuse.

## Core Tooling Rules

- Treat Vagrant as the orchestration layer and Ansible as the primary provisioner.
- Use shell scripting only for bootstrap or edge-case tasks that are not practical in Ansible.
- For Windows-side scripting, prefer PowerShell (`.ps1`).
- For Linux-side scripting, prefer Bash (`.sh`).

## Vagrant Standards

- Use `config.vm.provider "hyperv"` blocks for provider-specific settings.
- Set VM hardware and host integration settings in Hyper-V provider blocks, including RAM, CPU cores, and virtual switch selection.
- Prefer `config.vm.provision "ansible"` as the main provisioning phase.
- Add `config.vm.provision "shell"` only for targeted exceptions.
- Keep networking deterministic with static IPs and stable DNS naming for the local lab.

## Ansible Standards

- Always add descriptive `name:` fields for tasks so logs are clear and searchable.
- For Linux targets, prefer native Ansible modules over `shell` and `command` whenever possible.
- For Windows targets, use `win_` modules (for example `win_package`, `win_copy`) as the default approach.
- If Windows automation needs a lower-level action, use `win_shell` deliberately and explain why in the task name or nearby comment.

## Connectivity Assumptions

- Assume SSH connectivity for Linux guests.
- Assume WinRM (or OpenSSH when explicitly configured) for Windows guest management through Ansible.

## Idempotency and Safety

- Write playbooks and scripts to be idempotent and safe to run repeatedly.
- Avoid duplicate configuration side effects across repeated runs.
- Prefer module patterns that express desired state instead of imperative command chains.

## GitOps and Structure

- Keep Vagrantfiles, playbooks, roles, and scripts version-controlled.
- Favor modular roles and composable playbooks over large monolithic files.
- Propose changes in a structure suitable for pull-request workflows.

## Hyper-V and Windows Notes

- For Hyper-V networking, include logic to select the correct virtual switch, `smb_id`, or adapter mapping when the scenario requires it.
- For Windows tasks, surface when enabling a Windows Feature or using `win_shell` is more efficient than a generic module.
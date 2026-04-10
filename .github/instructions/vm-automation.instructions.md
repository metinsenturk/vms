---
description: "Use when working on VM lifecycle automation with Vagrant, Hyper-V, PowerShell, Bash, WinRM, SSH, static lab networking, and provisioning workflows."
name: "VM Automation Standards"
applyTo: "Vagrantfile, **/*.yml, **/*.yaml, **/*.ps1, **/*.sh"
---

# VM Automation Project Instructions

## Project Scope

- Build and maintain VM automation using Vagrant with the Hyper-V provider.
- Target mixed guest environments: Linux (Ubuntu or Debian) and Windows.
- Prefer Git-friendly, modular automation artifacts that are easy to review and reuse.

## Core Tooling Rules

- Treat Vagrant as the orchestration layer.
- Use shell scripting as the primary guest provisioning approach.
- For Windows-side scripting, prefer PowerShell (`.ps1`).
- For Linux-side scripting, prefer Bash (`.sh`).

## Vagrant Standards

- Use `config.vm.provider "hyperv"` blocks for provider-specific settings.
- Set VM hardware and host integration settings in Hyper-V provider blocks, including RAM, CPU cores, and virtual switch selection.
- Prefer script provisioning through shell provisioners or `vagrant ssh`-driven scripts.
- Keep networking deterministic with static IPs and stable DNS naming for the local lab.

## Connectivity Assumptions

- Assume SSH connectivity for Linux guests.
- Assume WinRM (or OpenSSH when explicitly configured) for Windows guest management.

## Idempotency and Safety

- Write playbooks and scripts to be idempotent and safe to run repeatedly.
- Avoid duplicate configuration side effects across repeated runs.
- Prefer explicit script checks that guard against repeated side effects.

## GitOps and Structure

- Keep Vagrantfiles and scripts version-controlled.
- Favor small reusable scripts over large monolithic files.
- Propose changes in a structure suitable for pull-request workflows.

## Hyper-V and Windows Notes

- For Hyper-V networking, include logic to select the correct virtual switch, `smb_id`, or adapter mapping when the scenario requires it.
- For Windows tasks, surface when enabling a Windows Feature or using `win_shell` is more efficient than a generic module.
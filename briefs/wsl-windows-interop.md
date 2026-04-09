---
title: WSL Windows Executable Interop
description: How WSL enables running Windows .exe binaries from Linux, when it is needed, and why it breaks.
created: 2026-04-09
updated: 2026-04-09
tags:
  - wsl
  - windows
  - interop
  - binfmt
  - vagrant
  - hyper-v
category: WSL
references:
  - https://learn.microsoft.com/en-us/windows/wsl/interop
  - https://learn.microsoft.com/en-us/windows/wsl/wsl-config
---

# WSL Windows Executable Interop

## What it is

WSL (Windows Subsystem for Linux) can execute Windows `.exe` and `.com` binaries
directly from a Linux shell — without any wrapper or path conversion. For example,
from inside WSL you can run:

```bash
powershell.exe -Command "Get-Date"
cmd.exe /c ver
notepad.exe
```

This is called **WSL Windows executable interop**.

## How it works

The mechanism relies on the Linux kernel feature **`binfmt_misc`**. During WSL
startup, a handler is registered under:

```
/proc/sys/fs/binfmt_misc/WSLInterop
```

This handler matches Windows PE (Portable Executable) binary format. When the
kernel sees an `exec()` call targeting a file that matches the PE magic bytes, it
hands execution off to the WSL host bridge process (`/init`) instead of trying to
run the binary natively. The bridge then launches the binary on the Windows side
through the normal Win32 subsystem.

## When it is needed

Interop is required whenever a Linux-side tool or script needs to call a
Windows-only binary. Common cases:

| Use case | Windows binary called |
|---|---|
| Vagrant with Hyper-V | `powershell.exe`, `vagrant.exe` |
| Opening files in Windows editors | `code.exe`, `notepad.exe` |
| Clipboard integration | `clip.exe` |
| Calling Windows package managers | `winget.exe`, `choco.exe` |
| Invoking Windows SDK tools | `msbuild.exe`, `signtool.exe` |

In a VM automation workflow, `vagrant up --provider=hyperv` **must** be run
through Windows-host Vagrant because Hyper-V management is a privileged Windows
operation. WSL-side automation calls `powershell.exe` to drive it.

## Checking interop status

```bash
# Is the WSLInterop binfmt handler registered and enabled?
cat /proc/sys/fs/binfmt_misc/WSLInterop

# Quick functional test
cmd.exe /c ver && echo "interop OK" || echo "interop BROKEN"

# Check config file
cat /etc/wsl.conf
```

Expected healthy output from the first command:

```
enabled
interpreter /init
flags: PF
```

## Why it breaks

### 1. Process-tree security restriction (most common)

Some processes call `prctl(PR_SET_NO_NEW_PRIVS)` as a security hardening step.
Linux treats this as a one-way flag that disables `binfmt_misc` handler execution
for the calling process **and all its descendants**. This means every terminal or
subprocess spawned under that process loses interop.

Common triggers:

| Tool | Why |
|---|---|
| VS Code Remote-WSL extension | Sets `NO_NEW_PRIVS` in its server launcher |
| Docker Desktop WSL integration | Sets it in its WSL backend process |
| Some systemd service units | Set it via `NoNewPrivileges=yes` |

**Symptom**: `cannot execute binary file: Exec format error` when running `.exe`.

**Fix**: Open a new WSL terminal launched directly from Windows (Start menu,
Windows Terminal, or `wsl.exe` from a standard cmd/PowerShell prompt) rather than
from inside VS Code or Docker.

### 2. Interop disabled in `/etc/wsl.conf`

```ini
[interop]
enabled=false
```

**Fix**: Set `enabled=true` (or remove the `[interop]` block), then restart WSL:

```powershell
wsl --shutdown
```

### 3. `WSLInterop` binfmt entry is disabled

The handler can be individually disabled at runtime:

```bash
cat /proc/sys/fs/binfmt_misc/WSLInterop  # shows "disabled"
```

**Fix** (non-persistent, resets on WSL restart):

```bash
echo 1 | sudo tee /proc/sys/fs/binfmt_misc/WSLInterop
```

### 4. WSL interop disabled globally

```bash
cat /proc/sys/fs/interop/enabled  # shows "0"
```

**Fix**: Re-enable and restart WSL.

## Path translation

When calling a Windows binary, if you pass a Linux path as an argument, WSL
automatically translates it to a Windows UNC path:

```
/home/user/file.txt  →  \\wsl.localhost\Ubuntu\home\user\file.txt
```

This works for most cases, but tools that use `PowerShell` or `cmd` to change
directory and then invoke further binaries may reject `\\wsl.localhost\` paths
(e.g. Vagrant's Hyper-V PowerShell scripts). The workaround is to pass a native
Windows path directly using the `D:\...` form, or to use `/mnt/<drive>/...`
paths on the Linux side.

## Quick diagnostic checklist

```
1. Was the terminal opened from Windows directly (not from VS Code / Docker)?
2. Is /etc/wsl.conf interop.enabled set to true?
3. Does `cat /proc/sys/fs/binfmt_misc/WSLInterop` show "enabled"?
4. Does `cmd.exe /c ver` succeed?
```

All four must pass for Windows executable interop to work reliably.

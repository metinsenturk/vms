# Task Engine Technical Guide

This document describes how the task system works internally and how to extend it safely.

## 1) Config vs Runner

The task system is intentionally split into two files:

- `tasks-config.ps1`: data only (manifest)
- `tasks.ps1`: execution logic (engine)

### `tasks-config.ps1` responsibilities

- Defines `$VM_CONFIGS`: alias -> metadata map with `Path` and `Desc`
- Defines `$RECIPES`: recipe name -> ordered command array
- Contains no orchestration control flow

Example shape:

```powershell
$VM_CONFIGS = @{
    'hub' = @{
        Path = "$PSScriptRoot\vms\hub-01"
        Desc = "Primary Message Hub & DB"
    }
}

$RECIPES = @{
    'cycle' = @(
        "vagrant halt",
        "vagrant up"
    )
}
```

### `tasks.ps1` responsibilities

- Parses CLI parameters
- Loads and validates config shape
- Resolves target alias to VM folder
- Runs recipe sequences with fail-fast behavior
- Proxies non-recipe actions directly to Vagrant
- Exposes special entry points: `help` and `doctor`

## 2) Recipe Mode vs Direct Vagrant Mode

Invocation format:

```text
.\tasks.ps1 <target> <action> [extra args]
```

Where:

- `<target>` is a key in `$VM_CONFIGS`
- `<action>` is either a recipe key in `$RECIPES` or a native Vagrant subcommand

### Recipe mode

If `<action>` exists in `$RECIPES`, the engine executes each command in order:

```powershell
.\tasks.ps1 hub audit
.\tasks.ps1 openfang rebuild
```

Behavior details:

- each command runs in the resolved VM folder
- command output is streamed to console
- first non-zero exit code aborts remaining steps

### Proxy mode

If `<action>` is not a recipe, it is forwarded as a Vagrant command:

```powershell
.\tasks.ps1 hub up
.\tasks.ps1 docker status
.\tasks.ps1 docker up --provider hyperv
```

Effective command pattern:

```text
vagrant <action> <extra args>
```

## 3) Internal Flow of `tasks.ps1`

The engine executes in these phases.

### Phase A: Parameter parsing

Parameters are positional:

- Position 0: `Target`
- Position 1: `Action`
- Position 2+: `ExtraArgs` (captured via `ValueFromRemainingArguments`)

Examples:

- `.\tasks.ps1 hub up`
- `.\tasks.ps1 docker ssh -c "uptime"`

### Phase B: Early exits for special commands

- `help` or empty target -> render usage/targets/recipes
- `doctor` -> run environment diagnostics and exit

`doctor` checks:

- admin token presence
- `vagrant`, `git`, `ssh` availability
- Hyper-V service (`vmms`) state
- virtual switch visibility

### Phase C: Config loading and validation

The engine dot-sources `tasks-config.ps1`, then validates:

- `$VM_CONFIGS` exists and is a hashtable
- `$RECIPES` is either missing (defaults to empty hashtable) or a hashtable

This prevents null/method errors at runtime.

### Phase D: Target resolution

- verifies target key exists in `$VM_CONFIGS`
- resolves VM path from `$VM_CONFIGS[$Target].Path`
- fails early if path does not exist

### Phase E: Execution wrapper

All execution goes through `Invoke-TargetCommand`:

- `Push-Location` into target VM folder
- `Invoke-Expression` on composed command
- capture `$LASTEXITCODE`
- normalize null to `0`
- `Pop-Location` in `finally`

This guarantees directory restoration even on failure.

### Phase F: Single status pre-check

For actions other than `up` and `status`, the engine runs one state check using:

```text
vagrant status --machine-readable
```

It extracts the state token (`running`, `poweroff`, `not_created`, etc.) and prints a warning if not running.

### Phase G: Action dispatch

- if action is recipe key: iterate commands with fail-fast
- otherwise: proxy to `vagrant <action> [extra args]`

### Phase H: Task boundary logs

- prints start timestamp
- prints finish timestamp

## 4) CMD Wrapper

`tasks.cmd` is a thin passthrough to preserve CMD compatibility:

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tasks.ps1" %*
```

Recommended argument order remains identical:

```cmd
tasks.cmd hub up
tasks.cmd docker status
```

## 5) Safe Extension Rules

- Add or update VM aliases only in `tasks-config.ps1`.
- Keep recipe commands explicit (`vagrant ...`) for readability.
- Treat recipe steps as atomic and order-dependent.
- Prefer adding recipes over embedding conditional business logic in `tasks.ps1`.
- Keep `tasks.ps1` generic: parse, validate, resolve, dispatch.
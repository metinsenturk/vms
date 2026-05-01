#requires -version 3.0
<#
.SYNOPSIS
    Vagrant Lab Proxy Engine - A centralized task runner for multi-VM environments.

.DESCRIPTION
    This script acts as an orchestration "Engine" that separates infrastructure data 
    from execution logic. It provides a single entry point to manage multiple Vagrant VMs.
    
    Key Features:
    1. Single-Check: Verifies VM status once at start-up to reduce wait times.[cite: 7]
    2. Fail-Fast: Aborts recipe execution immediately if any step returns a non-zero exit code.[cite: 7]
    3. Proxying: Passes any non-recipe command (and extra arguments) directly to Vagrant.[cite: 7]

.PARAMETER Target
    The VM alias defined in tasks-config.ps1 (e.g., 'hub', 'docker').[cite: 7]

.PARAMETER Action
    The specific recipe name to run (e.g., 'audit') or a native Vagrant command (e.g., 'up', 'ssh').[cite: 7]

.PARAMETER ExtraArgs
    Additional flags passed directly to the Vagrant executable (e.g., '--provider', '--force').[cite: 7]

.EXAMPLE
    .\tasks.ps1 hub audit
    Runs the 'audit' recipe for the hub VM, including disk checks and uptime.

.EXAMPLE
    .\tasks.ps1 docker up --provider hyperv
    Proxies the 'up' command to Vagrant for the docker VM with the Hyper-V provider flag.

.EXAMPLE
    .\tasks.ps1 base say-hello
    Runs the SSH-based greeting recipe on the base server.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$Target, # The VM alias defined in tasks-config.ps1 (e.g., 'hub')

    [Parameter(Position = 1, Mandatory = $true)]
    [string]$Action, # The command to run (e.g., 'up') or a recipe name (e.g., 'audit')

    [Parameter(Position = 2, ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs = @() # Captures any additional flags like --provider or -f
)

# --- 1. CONFIGURATION LOADING ---
# This "dot-sources" your manifest file, effectively importing the $VM_CONFIGS 
# and $RECIPES variables into this script's memory.
$configFile = Join-Path $PSScriptRoot "tasks-config.ps1"
if (Test-Path $configFile) {
    . $configFile
}
else {
    Write-Error "Configuration file not found: tasks-config.ps1"
    exit 1
}

# --- 2. TARGET RESOLUTION ---
# Validates that the requested VM alias exists in your configuration.
if (-not $VM_CONFIGS.ContainsKey($Target)) {
    Write-Host "Unknown VM alias '$Target'. Valid options: $($VM_CONFIGS.Keys -join ', ')" -ForegroundColor Red
    exit 1
}

# Resolves the physical path to the VM folder.
$vmPath = $VM_CONFIGS[$Target].Path
if (-not (Test-Path $vmPath)) {
    Write-Error "Path for $Target not found: $vmPath"
    exit 1
}

# --- 3. CORE EXECUTION WRAPPER ---
function Invoke-TargetCommand {
    <#
    This function handles the heavy lifting: switching directories, 
    executing the command, and returning the result.
    #>
    param([string]$CommandStr)

    Write-Host "`n[Target: $Target] Executing: $CommandStr" -ForegroundColor Cyan

    $localExitCode = 0
    $null = Push-Location $vmPath

    try {
        # Use PowerShell parsing so quoted subcommands (for example vagrant ssh -c '...')
        # are preserved correctly and only the numeric exit code is returned.
        Invoke-Expression $CommandStr | ForEach-Object { Write-Host $_ }
        $localExitCode = $LASTEXITCODE
    }
    finally {
        $null = Pop-Location
    }

    # Debugging: Uncomment the line below to see the raw exit code from the command execution.
    # Write-Host "[Debug] Raw Exit Code: $localExitCode" -ForegroundColor Gray

    # Standardize the exit code
    if ($null -eq $localExitCode) {
        $localExitCode = 0
    }

    if ($localExitCode -ne 0) {
        Write-Host "X Command failed on $Target (Exit Code: $localExitCode)" -ForegroundColor Red
    }

    return [int]$localExitCode
}

# --- START LOG ---
$StartTime = Get-Date -Format "HH:mm:ss"
Write-Host "[Task Started at $StartTime]" -ForegroundColor Gray
Write-Host "[Processing $Action for $Target... please wait]" -ForegroundColor Cyan

# --- 4. SINGLE-CHECK LOGIC ---
<# 
Pre-execution health check: We check the VM status once at the start of the script.
This prevents redundant "VM not running" warnings for every line in a recipe.
We skip this for 'up' (which starts the VM) and 'status' (which is redundant).[cite: 2]
#>
if ($Action -notmatch "up|status") {
    Push-Location $vmPath
    # Parse machine-readable output to find the state (e.g., running, poweroff, not_created).[cite: 2]
    $rawStatus = (vagrant status --machine-readable | Select-String ",state,(\w+)" | ForEach-Object { $_.Matches.Groups[1].Value })
    $status = $rawStatus -replace '_', ' ' # Make it human-friendly.[cite: 2]
    Pop-Location

    if ($status -ne "running") {
        Write-Host "[!] Warning: $Target is currently '$status'. Commands requiring SSH or Provisioning may fail." -ForegroundColor Yellow
    }
    else {
        Write-Host "[$Target is running]" -ForegroundColor Green
    }
}

# --- 5. ACTION RESOLUTION (RECIPE vs. PROXY) ---
if ($RECIPES.ContainsKey($Action)) {
    <# 
    RECIPE MODE: Iterates through the array of commands defined in the config.
    Includes FAIL-FAST logic to stop immediately if any step fails.[cite: 2]
    #>
    Write-Host "--- Running Recipe: $Action ---" -ForegroundColor Yellow
    
    foreach ($cmd in $RECIPES[$Action]) {
        # Force the result to be an Integer
        [int]$result = Invoke-TargetCommand -CommandStr $cmd
        
        # FAIL-FAST: If a command fails, abort the rest of the recipe to prevent chain-reaction errors.[cite: 2]
        if ($result -ne 0) {
            Write-Host "`n[!] Recipe Aborted: A command in the sequence failed." -ForegroundColor Red
            break
        }
    }
}
else {
    <# 
    PROXY MODE: Directly passes the command through to Vagrant.
    This allows usage like '.\tasks.ps1 hub up --provider=hyperv'[cite: 2]
    #>
    $fullArgs = if ($ExtraArgs) { "$Action $($ExtraArgs -join ' ')" } else { $Action }
    Invoke-TargetCommand -CommandStr "vagrant $fullArgs"
}

# --- END LOG ---
$EndTime = Get-Date -Format "HH:mm:ss"
Write-Host "`n[Task Finished at $EndTime]" -ForegroundColor Gray
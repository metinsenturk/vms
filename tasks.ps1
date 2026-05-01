#requires -version 3.0
<#
.SYNOPSIS
    Vagrant Lab Proxy Engine - A centralized task runner for multi-VM environments.
    
.DESCRIPTION
    This script acts as an "Engine" that separates infrastructure data (config) 
    from execution logic. It supports native Vagrant command proxying and 
    custom multi-step sequences called "Recipes."
#>
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Target, # The VM alias defined in tasks-config.ps1 (e.g., 'hub')

    [Parameter(Position=1, Mandatory=$true)]
    [string]$Action, # The command to run (e.g., 'up') or a recipe name (e.g., 'audit')

    [Parameter(Position=2, ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs = @() # Captures any additional flags like --provider or -f
)

# --- 1. CONFIGURATION LOADING ---
# This "dot-sources" your manifest file, effectively importing the $VM_CONFIGS 
# and $RECIPES variables into this script's memory.
$configFile = Join-Path $PSScriptRoot "tasks-config.ps1"
if (Test-Path $configFile) {
    . $configFile
} else {
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
    
    # Push-Location saves our current spot (root) before we enter the VM folder.[cite: 2]
    Push-Location $vmPath
    Invoke-Expression $CommandStr
    $exitCode = $LASTEXITCODE # Capture the result of the command (0 = success).[cite: 2]
    Pop-Location # Immediately return to the root folder.[cite: 2]
    
    if ($exitCode -ne 0) {
        Write-Host "X Command failed on $Target (Exit Code: $exitCode)" -ForegroundColor Red
    }
    
    # Return the exit code to the caller. This is the foundation for Fail-Fast.[cite: 2]
    return $exitCode 
}

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
    } else {
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
        $result = Invoke-TargetCommand -CommandStr $cmd
        
        # FAIL-FAST: If a command fails, abort the rest of the recipe to prevent chain-reaction errors.[cite: 2]
        if ($result -ne 0) {
            Write-Host "`n[!] Recipe Aborted: A command in the sequence failed." -ForegroundColor Red
            break
        }
    }
} else {
    <# 
    PROXY MODE: Directly passes the command through to Vagrant.
    This allows usage like '.\tasks.ps1 hub up --provider=hyperv'[cite: 2]
    #>
    $fullArgs = if ($ExtraArgs) { "$Action $($ExtraArgs -join ' ')" } else { $Action }
    Invoke-TargetCommand -CommandStr "vagrant $fullArgs"
}
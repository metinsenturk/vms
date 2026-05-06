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
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$Target = '', # The VM alias defined in tasks-config.ps1 (e.g., 'hub')

    [Parameter(Position = 1, Mandatory = $false)]
    [string]$Action = '', # The command to run (e.g., 'up') or a recipe name (e.g., 'audit')

    [Parameter(Position = 2, ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs = @() # Captures any additional flags like --provider or -f
)

# --- 0. HELP FUNCTION ---
function Show-Help {
    # Load config first so we can list live VMs and recipes
    $configFile = Join-Path $PSScriptRoot "tasks-config.ps1"
    if (Test-Path $configFile) { . $configFile }

    Write-Host ""
    Write-Host "Vagrant Lab Task Runner" -ForegroundColor Cyan
    Write-Host "Usage: .\tasks.ps1 <target> <action> [extra args]" -ForegroundColor White
    Write-Host ""

    Write-Host "Available Targets:" -ForegroundColor Yellow
    foreach ($key in ($VM_CONFIGS.Keys | Sort-Object)) {
        $desc = $VM_CONFIGS[$key].Desc
        Write-Host ("  {0,-15} {1}" -f $key, $desc)
    }
    Write-Host ""

    Write-Host "Available Recipes:" -ForegroundColor Yellow
    if ($RECIPES -and $RECIPES.Count -gt 0) {
        foreach ($key in ($RECIPES.Keys | Sort-Object)) {
            Write-Host ("  {0}" -f $key)
        }
    } else {
        Write-Host "  (none defined)"
    }
    Write-Host ""

    Write-Host "Native Vagrant Commands (proxy mode):" -ForegroundColor Yellow
    Write-Host "  Any command not listed as a recipe is passed directly to Vagrant."
    Write-Host "  Examples: up, halt, destroy, ssh, status, reload, provision"
    Write-Host ""

    Write-Host "Special Commands:" -ForegroundColor Yellow
    Write-Host "  .\tasks.ps1 help         Show this help message"
    Write-Host "  .\tasks.ps1 doctor       Check environment prerequisites and VM health"
    Write-Host ""

    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\tasks.ps1 hub audit"
    Write-Host "  .\tasks.ps1 docker up --provider hyperv"
    Write-Host "  .\tasks.ps1 base ssh"
    Write-Host ""
}

# --- 0b. DOCTOR FUNCTION ---
$script:doctorIssues = 0

function Write-Check {
    param([string]$Label, [string]$Status, [string]$Detail = '')
    $padded = "{0,-30}" -f $Label
    switch ($Status) {
        'OK'   { Write-Host "  [OK]   $padded $Detail" -ForegroundColor Green }
        'WARN' { Write-Host "  [WARN] $padded $Detail" -ForegroundColor Yellow; $script:doctorIssues++ }
        'FAIL' { Write-Host "  [FAIL] $padded $Detail" -ForegroundColor Red;    $script:doctorIssues++ }
    }
}

function Show-Doctor {
    $script:doctorIssues = 0

    Write-Host ""
    Write-Host "Doctor Report" -ForegroundColor Cyan
    Write-Host ("-" * 50)

    # --- Session ---
    Write-Host "`nSession:" -ForegroundColor Yellow
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Check "Running as Administrator" "OK" "Hyper-V operations permitted"
    } else {
        Write-Check "Running as Administrator" "FAIL" "Re-launch terminal as Administrator for Hyper-V"
    }

    # --- Tools ---
    Write-Host "`nTools:" -ForegroundColor Yellow

    # vagrant
    if (Get-Command vagrant -ErrorAction SilentlyContinue) {
        $vagrantVersion = (& vagrant --version) -replace 'Vagrant ', ''
        Write-Check "vagrant" "OK" $vagrantVersion
    } else {
        Write-Check "vagrant" "FAIL" "Not found on PATH -- install from https://www.vagrantup.com"
    }

    # git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitVersion = (& git --version) -replace 'git version ', ''
        Write-Check "git" "OK" $gitVersion
    } else {
        Write-Check "git" "WARN" "Not found on PATH -- needed for repo management"
    }

    # ssh (needed for vagrant ssh)
    if (Get-Command ssh -ErrorAction SilentlyContinue) {
        $sshVersion = (& ssh -V 2>&1) | Select-Object -First 1
        Write-Check "ssh" "OK" "$sshVersion"
    } else {
        Write-Check "ssh" "WARN" "Not found on PATH -- 'vagrant ssh' will not work"
    }

    # --- Hyper-V ---
    Write-Host "`nHyper-V:" -ForegroundColor Yellow

    $vmms = Get-Service -Name vmms -ErrorAction SilentlyContinue
    if ($null -eq $vmms) {
        Write-Check "Hyper-V (vmms service)" "FAIL" "Service not found -- Hyper-V may not be enabled"
    } elseif ($vmms.Status -eq 'Running') {
        Write-Check "Hyper-V (vmms service)" "OK" "Running"
    } else {
        Write-Check "Hyper-V (vmms service)" "WARN" "Service exists but status is '$($vmms.Status)'"
    }

    $extSwitch = $null
    try {
        $extSwitch = Get-VMSwitch -SwitchType External -ErrorAction Stop | Select-Object -First 1
    } catch {
        # Hyper-V PowerShell module unavailable or no switch found
    }
    if ($extSwitch) {
        Write-Check "External Virtual Switch" "OK" "$($extSwitch.Name)"
    } else {
        Write-Check "External Virtual Switch" "WARN" "None found -- VMs need an External switch for network"
    }

    # --- Summary ---
    Write-Host ""
    Write-Host ("-" * 50)
    if ($script:doctorIssues -eq 0) {
        Write-Host "  All checks passed. Environment is ready." -ForegroundColor Green
    } else {
        Write-Host "  $($script:doctorIssues) issue(s) found. Review warnings above." -ForegroundColor Yellow
    }
    Write-Host ""
}

# Show help when no arguments are provided or target is 'help'
if (-not $Target -or $Target -eq 'help') {
    Show-Help
    exit 0
}

# Run doctor checks when target is 'doctor'
if ($Target -eq 'doctor') {
    Show-Doctor
    exit 0
}

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

# Validate imported configuration shape to prevent null-method errors.
if (-not ($VM_CONFIGS -is [hashtable])) {
    Write-Error "Invalid configuration: `$VM_CONFIGS is missing or not a hashtable in tasks-config.ps1"
    exit 1
}

if ($null -eq $RECIPES) {
    $RECIPES = @{}
}
elseif (-not ($RECIPES -is [hashtable])) {
    Write-Error "Invalid configuration: `$RECIPES must be a hashtable when defined in tasks-config.ps1"
    exit 1
}

# Require Action now that we know Target is valid
if (-not $Action) {
    Write-Host "Error: <action> is required when <target> is specified." -ForegroundColor Red
    Write-Host "Run '.\tasks.ps1 help' to see usage." -ForegroundColor Gray
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
if ($Action -notin @('up', 'status')) {
    $rawStatus = $null
    $status = $null

    try {
        Push-Location $vmPath
        # Parse machine-readable output to find the state (e.g., running, poweroff, not_created).[cite: 2]
        $rawStatus = (vagrant status --machine-readable |
            Select-String ",state,(\w+)" |
            ForEach-Object { $_.Matches.Groups[1].Value })
    }
    finally {
        Pop-Location
    }

    # Select a single explicit state and make it human-friendly.[cite: 2]
    $status = @($rawStatus | Where-Object { $_ }) | Select-Object -First 1
    if ($status) {
        $status = $status -replace '_', ' '
    }
    else {
        $status = 'unknown'
    }

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
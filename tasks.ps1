#requires -version 3.0
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Target, # The VM Alias (e.g., hub)

    [Parameter(Position=1, Mandatory=$true)]
    [string]$Action, # The Command (e.g., up, status, or install-docker)

    [Parameter(Position=2, ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs = @()
)

# 1. Load the configuration
$configFile = Join-Path $PSScriptRoot "tasks-config.ps1"
if (Test-Path $configFile) {
    . $configFile
} else {
    Write-Error "Configuration file not found: tasks-config.ps1"
    exit 1
}

# 2. Resolve the VM Target
if (-not $VM_CONFIGS.ContainsKey($Target)) {
    Write-Host "Unknown VM alias '$Target'. Valid options: $($VM_CONFIGS.Keys -join ', ')" -ForegroundColor Red
    exit 1
}

$vmPath = $VM_CONFIGS[$Target].Path
if (-not (Test-Path $vmPath)) {
    Write-Error "Path for $Target not found: $vmPath"
    exit 1
}

# 3. Execution Logic
function Invoke-TargetCommand {
    param([string]$CommandStr)

    Write-Host "`n[Target: $Target] Executing: $CommandStr" -ForegroundColor Cyan
    
    Push-Location $vmPath
    Invoke-Expression $CommandStr
    $exitCode = $LASTEXITCODE
    Pop-Location
    
    if ($exitCode -ne 0) {
        Write-Host "X Command failed on $Target (Exit Code: $exitCode)" -ForegroundColor Red
    }
    
    return $exitCode # Crucial for Fail-Fast logic
}

# 4. Resolve Action (Recipe vs. Proxy)

# --- SINGLE-CHECK LOGIC ---
# Check status once before doing anything, unless we are explicitly running 'up' or 'status'
if ($Action -notmatch "up|status") {
    Push-Location $vmPath
    $rawStatus = (vagrant status --machine-readable | Select-String ",state,(\w+)" | ForEach-Object { $_.Matches.Groups[1].Value })
    $status = $rawStatus -replace '_', ' '
    Pop-Location

    if ($status -ne "running") {
        Write-Host "[!] Warning: $Target is currently '$status'. Commands requiring SSH or Provisioning may fail." -ForegroundColor Yellow
    } else {
        Write-Host "[$Target is running]" -ForegroundColor Green
    }
}

if ($RECIPES.ContainsKey($Action)) {
    # It's a Recipe: Run the sequence of commands
    Write-Host "--- Running Recipe: $Action ---" -ForegroundColor Yellow
    
    foreach ($cmd in $RECIPES[$Action]) {
        $result = Invoke-TargetCommand -CommandStr $cmd
        
        # --- FAIL-FAST LOGIC ---
        if ($result -ne 0) {
            Write-Host "`n[!] Recipe Aborted: A command in the sequence failed." -ForegroundColor Red
            break
        }
    }
} else {
    # It's a Proxy: Pass directly to Vagrant with extra arguments
    $fullArgs = if ($ExtraArgs) { "$Action $($ExtraArgs -join ' ')" } else { $Action }
    Invoke-TargetCommand -CommandStr "vagrant $fullArgs"
}
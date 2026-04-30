#requires -version 3.0
<#
.SYNOPSIS
    Windows-native VM automation for Vagrant + Hyper-V
.DESCRIPTION
    Replacement for Make-based workflow. Supports VM aliases and all standard
    Vagrant operations. Run from D:\vm-home in any PowerShell session - no WSL required.
.PARAMETER Command
    The command to run: up, halt, ssh, status, provision, destroy, vm-info,
    check-tools, doctor, help
.PARAMETER VM
    The VM alias: hub, base, docker, or 'all' for bulk operations
.PARAMETER ExtraArgs
    Additional arguments passed to the command (e.g., SSH command to run)
.EXAMPLE
    .\tasks.ps1 up hub
.EXAMPLE
    .\tasks.ps1 ssh hub "sudo systemctl status docker"
.EXAMPLE
    .\tasks.ps1 up all
.EXAMPLE
    .\tasks.ps1 vm-info hub
#>

[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('up','halt','ssh','status','provision','destroy','vm-info','help','check-tools','doctor')]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$VM = '',

    [Parameter(Position=2, ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs = @()
)

# VM alias mapping - add new VMs here
$VM_ALIASES = @{
    'hub'    = 'hub-01'
    'base'   = 'base-server-01'
    'docker' = 'docker-server-01'
    'ubuntu' = 'my-ubuntu-box'
}

# Get all valid alias names
$VALID_ALIASES = @($VM_ALIASES.Keys) + @('all')



# Validate VM alias
function Assert-ValidVM {
    param([string]$VMAlias)
    
    if ($VMAlias -eq 'all') { return }
    if (-not $VM_ALIASES.ContainsKey($VMAlias)) {
        Write-Error "Unknown VM alias '$VMAlias'. Valid options: $($VALID_ALIASES -join ', ')"
        exit 1
    }
}

# Get VM directory path
function Get-VMDirectory {
    param([string]$VMAlias)
    $vmName = $VM_ALIASES[$VMAlias]
    return Join-Path $PSScriptRoot "vms\$vmName"
}

# Run vagrant command in specific VM directory.
# Uses direct invocation (not Start-Process) so that interactive sessions
# like 'vagrant ssh' inherit the calling terminal correctly.
function Invoke-VagrantCommand {
    param(
        [string]$VMAlias,
        [string]$VagrantCmd,
        [string[]]$VagrantArgs = @()
    )

    $vmDir  = Get-VMDirectory $VMAlias
    $vmName = $VM_ALIASES[$VMAlias]

    if (-not (Test-Path $vmDir)) {
        Write-Error "VM directory not found: $vmDir"
        exit 1
    }

    Write-Host "[$vmName] Running: vagrant $VagrantCmd $($VagrantArgs -join ' ')" -ForegroundColor Cyan

    Push-Location $vmDir
    & vagrant $VagrantCmd @VagrantArgs
    $vagrantExit = $LASTEXITCODE
    Pop-Location
    if ($vagrantExit -ne 0) {
        Write-Error "Vagrant command failed with exit code $vagrantExit"
        exit $vagrantExit
    }
}

# Bulk operations for all VMs
function Invoke-BulkOperation {
    param(
        [string]$Operation,
        [string[]]$VagrantArgs = @()
    )

    Write-Host "Running '$Operation' for all VMs: $($VM_ALIASES.Keys -join ', ')" -ForegroundColor Yellow

    foreach ($alias in $VM_ALIASES.Keys) {
        Write-Host "`n=== Processing VM: $alias ===" -ForegroundColor Green
        try {
            Invoke-VagrantCommand -VMAlias $alias -VagrantCmd $Operation -VagrantArgs $VagrantArgs
        }
        catch {
            Write-Warning "Operation '$Operation' failed for VM '$alias': $_"
            # Continue with remaining VMs on non-destructive operations
            if ($Operation -in @('up', 'provision', 'status')) {
                continue
            } else {
                throw
            }
        }
    }
}

# SSH with optional command
function Invoke-SSHCommand {
    param(
        [string]$VMAlias,
        [string[]]$SSHArgs
    )

    if ($VMAlias -eq 'all') {
        if ($SSHArgs.Count -eq 0) {
            Write-Error "SSH to 'all' requires a command. Example: .\tasks.ps1 ssh all 'uptime'"
            exit 1
        }
        $command = $SSHArgs -join ' '
        Invoke-BulkOperation -Operation 'ssh' -VagrantArgs @('-c', "`"$command`"")
    } else {
        $sshPassArgs = if ($SSHArgs.Count -gt 0) { @('-c', "`"$($SSHArgs -join ' ')`"") } else { @() }
        Invoke-VagrantCommand -VMAlias $VMAlias -VagrantCmd 'ssh' -VagrantArgs $sshPassArgs
    }
}

# Check for required tools
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Test Vagrant
    $vagrantExe = Get-Command 'vagrant' -ErrorAction SilentlyContinue
    if (-not $vagrantExe) {
        Write-Error "[FAIL] Vagrant not found. Install from https://developer.hashicorp.com/vagrant/install"
        exit 1
    }
    $vagrantVersion = (& vagrant --version 2>&1) | Select-Object -First 1
    Write-Host "[OK] Vagrant found: $vagrantVersion" -ForegroundColor Green

    # Test Hyper-V (basic check)
    if (-not (Get-Command 'Get-VM' -ErrorAction SilentlyContinue)) {
        Write-Warning "[WARN] Hyper-V PowerShell module not available. Ensure Hyper-V is enabled."
    } else {
        Write-Host "[OK] Hyper-V PowerShell module available" -ForegroundColor Green
    }
    
    Write-Host "Prerequisites check completed." -ForegroundColor Green
}

# Show help
function Show-Help {
    Write-Host @"
VM Automation Tasks (Windows-native)

USAGE:
    .\tasks.ps1 <command> [vm] [args...]

COMMANDS:
    up <vm>            - Start VM (vm: hub|base|docker|all)
    halt <vm>          - Stop VM
    ssh <vm> [cmd]     - SSH to VM, optionally run command
    status <vm>        - Show VM status
    provision <vm>     - Run VM provisioning
    destroy <vm>       - Destroy VM (with confirmation)
    vm-info <vm>       - Run /vagrant/scripts/vm-info.sh in VM
    help               - Show this help
    check-tools        - Verify required tools are installed
    doctor             - Detailed system diagnostics

VM ALIASES:
"@ -ForegroundColor White

    foreach ($alias in $VM_ALIASES.GetEnumerator() | Sort-Object Key) {
        Write-Host "    $($alias.Key.PadRight(8)) -> $($alias.Value)" -ForegroundColor Cyan
    }

    Write-Host @"

EXAMPLES:
    .\tasks.ps1 up hub                    # Start hub-01 VM
    .\tasks.ps1 ssh hub "sudo systemctl status docker"  # Run command via SSH
    .\tasks.ps1 up all                    # Start all VMs
    .\tasks.ps1 halt all                  # Stop all VMs
    .\tasks.ps1 status base               # Check base-server-01 status

ENVIRONMENT:
    All configuration is hardcoded in the respective Vagrantfile under vms\<name>\.
    To override the Vagrant provider, set the PROVIDER environment variable in your shell.

"@ -ForegroundColor White
}

# Detailed diagnostics
function Test-Doctor {
    Write-Host "=== VM Automation Diagnostics ===" -ForegroundColor Yellow
    
    # Check current directory and VM dirs
    Write-Host "`nEnvironment:" -ForegroundColor White
    Write-Host "  Script location: $PSScriptRoot"
    
    # Check VM directories
    Write-Host "`nVM Directories:" -ForegroundColor White
    foreach ($alias in $VM_ALIASES.GetEnumerator()) {
        $vmDir = Get-VMDirectory $alias.Key
        $exists = Test-Path $vmDir
        $status = if ($exists) { "Found" } else { "Missing" }
        $color = if ($exists) { "Green" } else { "Red" }
        Write-Host "  $($alias.Key) ($($alias.Value)): $status" -ForegroundColor $color
        
        if ($exists) {
            $vagrantfile = Join-Path $vmDir 'Vagrantfile'
            if (Test-Path $vagrantfile) {
                Write-Host "    Vagrantfile: Found" -ForegroundColor Green
            } else {
                Write-Host "    Vagrantfile: Missing" -ForegroundColor Red
            }
        }
    }
    
    # Run basic tool check
    Write-Host "`nTools:" -ForegroundColor White
    Test-Prerequisites
}

# Main execution
try {
    # Load environment variables
    # Resolve provider (from shell env PROVIDER or default to hyperv)
    $provider = if ($env:PROVIDER) { $env:PROVIDER } else { 'hyperv' }

    switch ($Command) {
        'help' {
            Show-Help
            exit 0
        }
        'check-tools' {
            Test-Prerequisites
            exit 0  
        }
        'doctor' {
            Test-Doctor
            exit 0
        }
        default {
            # Validate VM parameter for commands that need it
            if ($VM -eq '') {
                Write-Error "VM parameter required. Use 'help' for usage information."
                exit 1
            }
            
            # Validate VM alias
            if ($VM -ne 'all') {
                Assert-ValidVM -VMAlias $VM
            }
            
            # Execute the command
            switch ($Command) {
                'up' {
                    if ($VM -eq 'all') {
                        Invoke-BulkOperation -Operation 'up' -VagrantArgs @("--provider=$provider")
                    } else {
                        Invoke-VagrantCommand -VMAlias $VM -VagrantCmd 'up' -VagrantArgs @("--provider=$provider")
                    }
                }
                'halt' {
                    if ($VM -eq 'all') {
                        Invoke-BulkOperation -Operation 'halt'
                    } else {
                        Invoke-VagrantCommand -VMAlias $VM -VagrantCmd 'halt'
                    }
                }
                'ssh' {
                    Invoke-SSHCommand -VMAlias $VM -SSHArgs $ExtraArgs
                }
                'status' {
                    if ($VM -eq 'all') {
                        Invoke-BulkOperation -Operation 'status'
                    } else {
                        Invoke-VagrantCommand -VMAlias $VM -VagrantCmd 'status'
                    }
                }
                'provision' {
                    if ($VM -eq 'all') {
                        Invoke-BulkOperation -Operation 'provision'
                    } else {
                        Invoke-VagrantCommand -VMAlias $VM -VagrantCmd 'provision'
                    }
                }
                'destroy' {
                    # Prompt for confirmation before destroying
                    $vmLabel = if ($VM -eq 'all') { 'ALL VMs' } else { $VM_ALIASES[$VM] }
                    $confirm = Read-Host "Are you sure you want to destroy $vmLabel? [y/N]"
                    if ($confirm -match '^[yY]') {
                        if ($VM -eq 'all') {
                            Invoke-BulkOperation -Operation 'destroy' -VagrantArgs @('-f')
                        } else {
                            Invoke-VagrantCommand -VMAlias $VM -VagrantCmd 'destroy' -VagrantArgs @('-f')
                        }
                    } else {
                        Write-Host "Destroy cancelled." -ForegroundColor Yellow
                    }
                }
                'vm-info' {
                    if ($VM -eq 'all') {
                        Invoke-BulkOperation -Operation 'ssh' -VagrantArgs @('-c', '"bash /vagrant/scripts/vm-info.sh"')
                    } else {
                        Invoke-VagrantCommand -VMAlias $VM -VagrantCmd 'ssh' -VagrantArgs @('-c', '"bash /vagrant/scripts/vm-info.sh"')
                    }
                }
            }
        }
    }
}
catch {
    Write-Error "Task failed: $_"
    exit 1
}
<#
.SYNOPSIS
    Vagrant Lab Manifest - Configuration data for the Proxy Engine.

.DESCRIPTION
    This file contains the "Source of Truth" for the lab environment. It is divided 
    into two main hash tables:
    
    $VM_CONFIGS: Maps human-readable aliases to physical file system paths.[cite: 8]
    $RECIPES: Defines sequences of commands (recipes) that the Engine can execute.[cite: 8]

.NOTES
    - When adding new Recipes, ensure sub-commands that use variables (like `$(hostname)`) 
      use the backtick (`) to escape the dollar sign so it executes inside the VM.[cite: 8]
    - Paths are resolved relative to the script root ($PSScriptRoot).[cite: 8]
#>

# VM Inventory: Map aliases to their real folders and add metadata
$VM_CONFIGS = @{
    'hub'    = @{ 
        Path = "$PSScriptRoot\vms\hub-01"; 
        Desc = "Primary Message Hub & DB" 
    }
    'docker' = @{ 
        Path = "$PSScriptRoot\vms\docker-server-01"; 
        Desc = "Docker Container Host" 
    }
    'base'   = @{ 
        Path = "$PSScriptRoot\vms\base-server-01"; 
        Desc = "Base Server Template" 
    }
    'openfang' = @{ 
        Path = "$PSScriptRoot\vms\openfang-01"; 
        Desc = "OpenFANG CTF Target" 
    }
    'myubuntubox' = @{ 
        Path = "$PSScriptRoot\vms\my-ubuntu-box"; 
        Desc = "Personal Ubuntu VM" 
    }
}

# Recipes: Custom task sequences (The "Makefile" logic)
# Note: These strings include 'vagrant' explicitly for transparency
$RECIPES = @{
    'install-docker' = @(
        "vagrant up --provision-with install-docker",
        "vagrant up --provision-with docker-info"
    )
    'say-hello' = @(
        "vagrant ssh -c 'echo hello from `$(hostname)'"
    )
    'rebuild' = @(
        "vagrant destroy -f",
        "vagrant up"
    )
    'audit' = @(
        "vagrant ssh -c 'df -h | grep /dev/sda'",
        "vagrant ssh -c 'uptime'",
        "vagrant ssh -c 'last -n 5'"
    )
    'cycle' = @(
        "vagrant halt",
        "vagrant up"
    )
}
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
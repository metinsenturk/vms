---
title: Hyper-V linked_clone in Vagrant
description: How linked_clone works with Hyper-V, including first install behavior, deletion behavior, and tradeoffs.
created: 2026-04-21
updated: 2026-04-21
tags:
  - vagrant
  - hyper-v
  - linked-clone
  - differencing-disk
  - virtualization
category: Virtualization
references:
  - https://developer.hashicorp.com/vagrant/docs/providers/hyperv/configuration
  - https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-virtual-hard-disks
---

# Hyper-V linked_clone in Vagrant

## What linked_clone means

In the Hyper-V provider, `linked_clone` controls how the VM disk is created from the box image.

- `linked_clone = false` (default): Vagrant copies (full clone) the box VHD into a VM-specific VHD.
- `linked_clone = true`: Vagrant creates a Hyper-V differencing disk (child disk) that points to the box VHD (parent disk).

The provider docs describe this as using a differencing disk instead of cloning the entire VHD.

## First install behavior

This section describes the first `vagrant up --provider=hyperv` for a machine.

### With linked_clone disabled

What happens:
1. Vagrant imports the box (if not already present).
2. Vagrant creates a full VM disk by cloning/copying the box VHD.
3. Hyper-V boots the VM from that full clone.

Impact:
- Slower initial provisioning because a full disk copy is performed.
- Higher disk usage per VM.
- VM disk is independent from the parent box disk after creation.

### With linked_clone enabled

What happens:
1. Vagrant imports the box (if not already present).
2. Vagrant creates a differencing disk for the VM.
3. The differencing disk stores only changes; reads for unchanged blocks come from the parent box VHD.

Impact:
- Faster initial provisioning because no full clone copy is needed.
- Lower disk usage for additional VMs built from the same box.
- VM now depends on parent disk chain integrity.

## Deletion behavior

This section describes `vagrant destroy` behavior in practical terms.

### Without linked_clone

- Hyper-V VM is removed.
- VM-specific full-clone disk is removed.
- Box image remains in Vagrant box storage unless you remove the box explicitly.

### With linked_clone

- Hyper-V VM is removed.
- VM-specific differencing disk is removed.
- Parent box VHD remains and can be reused by other VMs.

Important dependency note:
- Existing linked clones depend on the parent VHD.
- Removing or corrupting the parent box VHD can break linked-clone VMs.

## Advantages and disadvantages

### Advantages of linked_clone = true

- Faster first boot for each new VM.
- Much lower disk usage when you run many similar VMs.
- Efficient for disposable lab/test machines.

### Disadvantages of linked_clone = true

- Parent-child dependency chain adds fragility.
- Backups and migration can be more complex because disk relationships matter.
- Parent disk lifecycle must be managed carefully.

### Advantages of linked_clone = false

- VM disk is self-contained after clone.
- Simpler portability and isolation at disk level.
- Fewer surprises if parent box artifacts are cleaned up.

### Disadvantages of linked_clone = false

- Slower provisioning for each VM.
- Significantly higher storage consumption at scale.

## Example

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"

  config.vm.provider "hyperv" do |h|
    h.vmname = "lab-node-01"
    h.memory = 4096
    h.cpus = 2

    # Toggle this based on your goal:
    # true  -> differencing disk (faster, smaller, parent-dependent)
    # false -> full clone disk (slower, larger, more independent)
    h.linked_clone = true
  end
end
```

Practical decision rule:
- Use `linked_clone = true` for fast, disposable environments where parent box stability is controlled.
- Use `linked_clone = false` for long-lived VMs where independence and portability are more important than provisioning speed.

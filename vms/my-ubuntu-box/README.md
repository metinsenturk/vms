# my-ubuntu-box

`my-ubuntu-box` is a minimal Vagrant example used to demonstrate the simplest possible Ubuntu VM setup in this repository.

## What It Does

- Uses the `generic/ubuntu2204` box
- Sets the guest hostname to `my-ubuntu-box`
- Runs a simple shell provisioner that prints `hello, <hostname>`

## Requirements

- Vagrant installed on the host machine
- A supported Vagrant provider installed and available

## Files

- `Vagrantfile`: Defines the VM and inline provisioning step

## How To Use

Start the VM:

```bash
vagrant up
```

Connect to the VM:

```bash
vagrant ssh
```

Re-run provisioning:

```bash
vagrant provision
```

Stop the VM:

```bash
vagrant halt
```

Remove the VM:

```bash
vagrant destroy -f
```

## Expected Provisioning Output

During provisioning, the shell provisioner prints a message similar to:

```text
hello, my-ubuntu-box
```

## Purpose

This VM is intended as a blog-friendly example. It stays intentionally small so the basic Vagrant concepts are easy to see without extra provider, networking, or provisioning complexity.
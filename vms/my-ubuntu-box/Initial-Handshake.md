
# Vagrant Initial Handshake

When `vagrant up` is first run, Vagrant bootstraps a secure SSH connection to the VM through a two-phase key exchange. It starts with an insecure default key shipped with the box, immediately replaces it with a freshly generated key pair, and from that point on all communication uses the new secure key.

The diagram below illustrates this process for the `my-ubuntu-box` VM.

```mermaid
---
config:
  layout: elk
  look: neo
  fontFamily: '''Source Code Pro Variable'', monospace'
  themeVariables:
    fontFamily: '''Source Code Pro Variable'', monospace'
---
sequenceDiagram
    autonumber
    participant User
    participant Vagrant
    participant VM as Virtual Machine
    User->>Vagrant: vagrant up
    Vagrant->>VM: SSH connection attempt
    Note over Vagrant,VM: Initial Handshake<br/>(Insecure Key)
    VM->>VM: Check authorized_keys<br/>for insecure public key
    VM-->>Vagrant: SSH connection accepted
    Vagrant->>Vagrant: Generate new<br/>private key pair
    Note over Vagrant: Private Key Generated
    Vagrant->>VM: Connect via insecure key<br/>& remove old key
    Vagrant->>VM: Add new public key to<br/>authorized_keys file
    VM->>VM: Replace insecure key<br/>with new public key
    VM-->>Vagrant: authorized_keys updated
    Note over Vagrant,VM: Secure Connection Ready
    Vagrant->>VM: SSH connection via<br/>new private key
    VM-->>Vagrant: SSH connection accepted
    Vagrant-->>User: VM provisioned & secure
```
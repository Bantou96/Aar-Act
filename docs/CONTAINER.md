# The container image

An execution environment with Ansible and the required collections already
present, for running the toolkit without installing anything on the control
machine.

Set `AARTOOL_HOME` to wherever the toolkit is mounted and `aartool` works the
same as it does on a host.

---

## Docker Execution Environment (no install)

If you don't want to install Ansible locally, pull the pre-built Docker image:

```bash
docker pull ghcr.io/cyberaar/ee-hardening:latest
```

**Dry-run hardening against a remote host (no changes):**

```bash
docker run --rm -it \
  -v ~/.ssh:/root/.ssh:ro \
  -v $(pwd)/ansible-hardening/inventory:/inventory:ro \
  ghcr.io/cyberaar/ee-hardening:latest \
  ansible-playbook \
    -i /inventory/hosts \
    --extra-vars "target=myserver" \
    -u admin -b --check \
    /usr/share/cyberaar/playbooks/2_configure_hardening.yml
```

**Full pipeline (baseline → harden → baseline):**

```bash
docker run --rm -it \
  -v ~/.ssh:/root/.ssh:ro \
  -v $(pwd)/ansible-hardening/inventory:/inventory:ro \
  -v $(pwd)/reports:/reports \
  ghcr.io/cyberaar/ee-hardening:latest \
  ansible-playbook \
    -i /inventory/hosts \
    --extra-vars "target=myserver baseline_output_dir=/reports" \
    -u admin -b \
    /usr/share/cyberaar/playbooks/0_execute_full_pipeline.yml
```

> Full reference: [`execution-environment/README.md`](../execution-environment/README.md)

---

---

## Prerequisites

### Control node (where you run Ansible)

```bash
# Python 3.8+ and Ansible 2.14+
pip install ansible

# Required Ansible collections (run once)
ansible-galaxy collection install -r ansible-hardening/requirements.yml
# Installs: ansible.posix >=1.5.4  |  community.general >=8.0.0
```

### Your inventory

`ansible-hardening/inventory/hosts` is **gitignored**, because it names real
machines. A fresh clone does not have one. Start from the template:

```bash
cp ansible-hardening/inventory/hosts.example ansible-hardening/inventory/hosts
```

Then edit it: the example lists two placeholder hosts and the group layout. The
format is INI on purpose, being the easiest thing to read over a colleague's
shoulder and to correct at three in the morning.

Note that `dmz_servers` is deliberately not part of `linux_servers`, so a
fleet-wide run does not reach a DMZ host by accident.

### Managed nodes (the servers being hardened)

- **RHEL 9 family**: RHEL 9, AlmaLinux 9, Rocky Linux 9
- **Ubuntu/Debian**: Ubuntu 20.04, 22.04, 24.04, Debian 11, 12
- Python 3 installed
- SSH access with a sudo-capable admin user
- No agent required, push-based via SSH

---

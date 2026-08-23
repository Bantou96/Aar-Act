# The container image

`ghcr.io/cyberaar/aartool` is the whole toolkit in a container: `aartool`,
Ansible, the 52 hardening roles and the audit script, with nothing to install on
the control machine.

The collection inside is built from the same commit the image is tagged with,
not pulled from Galaxy, so the image and the tag cannot disagree.

---

## Running it

The image *is* `aartool`: it is the entrypoint, so the command reads as the
command it is. Nothing needs installing on the control machine, not even
Ansible.

```bash
docker pull ghcr.io/cyberaar/aartool:latest
docker run --rm ghcr.io/cyberaar/aartool --version
```

`ghcr.io/cyberaar/ee-hardening` is still published under the same digest, so
anything already pulling that name keeps working.

**Audit a remote host.** Changes nothing.

```bash
docker run --rm \
  -v ~/.ssh:/keys:ro \
  -v "$(pwd)/reports:/reports" \
  ghcr.io/cyberaar/aartool \
  inspect --host 10.0.1.10 --user admin --ssh-key /keys/id_ed25519 -o /reports
```

**Audit a private host through a bastion**, which is how most estates are shaped:

```bash
docker run --rm \
  -v ~/.ssh:/keys:ro -v "$(pwd)/reports:/reports" \
  ghcr.io/cyberaar/aartool \
  inspect --host 10.0.1.31 --user admin --ssh-key /keys/id_ed25519 \
          --jump admin@bastion.example.com -o /reports
```

**Turn the report into a plan:**

```bash
docker run --rm -v "$(pwd)/reports:/reports" \
  ghcr.io/cyberaar/aartool advise /reports/cyberaar-*.json --target web-01 --user admin
```

**Preview and apply hardening.** The inventory is not in the image, by design:
it names real machines, so it is gitignored and excluded from the build. Mount
yours.

```bash
docker run --rm \
  -v ~/.ssh:/keys:ro \
  -v "$(pwd)/ansible-hardening/inventory:/opt/aartool/ansible-hardening/inventory:ro" \
  ghcr.io/cyberaar/aartool \
  plan --target web-01 --user admin
```

**Check the image can do what you are about to ask of it:**

```bash
docker run --rm ghcr.io/cyberaar/aartool doctor
```

On a fresh image `doctor` reports the inventory as missing and prints the
command to create one. That is correct, and the same thing a fresh clone does.

### Reaching the playbooks directly

The entrypoint is `aartool`; override it to run anything else in the image.

```bash
docker run --rm -it \
  -v ~/.ssh:/keys:ro \
  -v "$(pwd)/ansible-hardening/inventory:/inventory:ro" \
  --entrypoint ansible-playbook \
  ghcr.io/cyberaar/aartool \
    -i /inventory/hosts --extra-vars "target=myserver" -u admin -b --check \
    /opt/aartool/ansible-hardening/playbooks/2_configure_hardening.yml
```

The toolkit lives at `/opt/aartool` laid out exactly as in the repository, with
`AARTOOL_HOME` pointing at it. `aartool` locates the playbooks, the audit script
and the dashboard by walking up from its own file, so the layout is load-bearing
rather than cosmetic.

### What is not in the image

`ansible-hardening/inventory/hosts` and any `reports/`. Both are excluded by
`.dockerignore`, because `docker build` does not honour `.gitignore` and a local
build would otherwise bake the operator's own estate, hostnames and audit
findings included, into an image they might then push.

> Full reference: [`execution-environment/README.md`](../execution-environment/README.md)

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

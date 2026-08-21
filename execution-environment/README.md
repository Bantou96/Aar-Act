# CyberAar Execution Environment

A self-contained container image with everything needed to run CyberAar hardening, no local Ansible install required.

**Image:** `ghcr.io/cyberaar/ee-hardening` (GitHub Container Registry)

**Includes:**
- `ansible-core` (via base image)
- `cyberaar.hardening` collection, 51 CIS-aligned hardening roles
- `ansible.posix` + `community.general` dependencies
- CyberAar playbooks at `/usr/share/cyberaar/playbooks/`
- `cyberaar-baseline` audit script at `/usr/local/bin/cyberaar-baseline`

---

## Prerequisites

Docker or Podman installed on the control node. No Python, no Ansible, no pip.

---

## Quick start

### 1. Run a baseline audit on a remote host

```bash
docker run --rm \
  -v ~/.ssh:/root/.ssh:ro \
  ghcr.io/cyberaar/ee-hardening:latest \
  cyberaar-baseline --host 10.0.1.10 --user admin \
  --html-out /tmp/report.html --json-out /tmp/report.json
```

### 2. Dry-run hardening (check mode: no changes)

Create a minimal inventory file:

```ini
# inventory/hosts
[linux_servers]
myserver ansible_host=10.0.1.10
```

Then run:

```bash
docker run --rm -it \
  -v ~/.ssh:/root/.ssh:ro \
  -v $(pwd)/inventory:/inventory:ro \
  ghcr.io/cyberaar/ee-hardening:latest \
  ansible-playbook \
    -i /inventory/hosts \
    --extra-vars "target=myserver" \
    -u admin -b --check \
    /usr/share/cyberaar/playbooks/2_configure_hardening.yml
```

### 3. Apply full pipeline (baseline → harden → baseline)

```bash
docker run --rm -it \
  -v ~/.ssh:/root/.ssh:ro \
  -v $(pwd)/inventory:/inventory:ro \
  -v $(pwd)/reports:/reports \
  ghcr.io/cyberaar/ee-hardening:latest \
  ansible-playbook \
    -i /inventory/hosts \
    --extra-vars "target=myserver baseline_output_dir=/reports" \
    -u admin -b \
    /usr/share/cyberaar/playbooks/0_execute_full_pipeline.yml
```

---

## Available tags

| Tag | Description |
|---|---|
| `latest` | Latest stable release |
| `v2.0.0` | Pinned to collection v2.0.0 |

---

## Build locally

From the **repo root**:

```bash
docker build \
  -f execution-environment/Containerfile \
  --build-arg COLLECTION_VERSION=2.0.0 \
  -t ghcr.io/cyberaar/ee-hardening:latest \
  .
```

---

## Base image

Built on `python:3.11-slim` with `ansible-core` and `openssh-client` installed on top.

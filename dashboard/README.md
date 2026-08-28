# CyberAar Security Dashboard

A single-file, zero-dependency web dashboard for visualising `aartool-baseline` JSON reports.

**No install, no server, no internet required**: open `index.html` in any modern browser.

---

## How to use

### 1. Generate JSON reports

```bash
# Local machine
sudo aartool-baseline --json-out /tmp/$(hostname)-before.json

# Remote host via Ansible
ansible-playbook -i ansible-hardening/inventory/hosts \
  --extra-vars "target=myserver" -u admin -b \
  ansible-hardening/playbooks/1_execute_baseline_before.yml
```

### 2. Open the dashboard

```bash
# Option A: open directly (works for local file loading)
xdg-open dashboard/index.html          # Linux
open dashboard/index.html              # macOS

# Option B: serve locally (needed if files are on a remote path)
python3 -m http.server 8080 --directory dashboard/
# Then open http://localhost:8080
```

### 3. Load reports

- Click **Load Reports** or drag & drop `.json` files onto the dashboard
- Load multiple files from different hosts, each host gets its own card
- Load a **before** and **after** report for the same host → automatic comparison view

---

## Features

| Feature | Description |
|---|---|
| Fleet overview | Score ring + PASS/WARN/FAIL counts per host, sorted worst-first |
| Before/After delta | Automatic when two reports for same host are loaded; shows score delta pill |
| Host detail panel | Click any host card: slide-in panel with full check breakdown |
| Status filter | Filter checks by FAIL / WARN / PASS inside the detail panel |
| Ansible command | Copy-ready `ansible-playbook` command pre-filled with host and inventory |
| PDF export | Browser print → PDF (header and panel hidden automatically) |

---

## Before/After comparison

Load the pre-hardening and post-hardening reports for the same host simultaneously:

```
reports/before/myserver/report.json   →  load both
reports/after/myserver/report.json    →
```

The dashboard groups them by `host` field and sorts by `date`: the oldest report is "Before", the newest is "After".

---

## Offline use

`index.html` has no external dependencies (no CDN, no npm, no build step). It works completely offline, ideal for air-gapped environments.

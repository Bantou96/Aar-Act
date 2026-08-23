# The offline dashboard

A single HTML file that renders audit reports with no server, no build step and
no external requests, so it works on an isolated network.

`aartool report --out fleet.html` bakes results straight into a copy of it,
producing one file you can email; see [AARTOOL.md](AARTOOL.md#report). This
document covers using the dashboard by hand.

---

## Security Dashboard

`dashboard/index.html` is a single-file, zero-dependency web dashboard for visualising baseline reports across your entire fleet. No install, no server, no internet connection required.

### Features

| Feature | Description |
|---|---|
| Fleet overview | Score ring per host (green ≥ 80%, amber ≥ 60%, red < 60%), PASS / WARN / FAIL counts, sorted worst-first |
| Before/After delta | Load a pre- and post-hardening report for the same host: score delta pill appears automatically |
| Host detail panel | Click any host card: slide-in panel with full check table |
| Status filter | Filter checks by FAIL / WARN / PASS inside the detail panel |
| Ansible remediation | Copy-ready `ansible-playbook` command pre-filled with hostname and inventory path |
| PDF export | Browser print → PDF (header and panel hidden automatically) |
| Fully offline | No CDN, no npm, no build step: works in air-gapped environments |

---

### Step 1: Generate JSON reports

```bash
# Run directly on the local machine
sudo bash scripts/cyberaar-baseline.sh \
  --json-out /tmp/before-$(hostname).json

# Or via Ansible (pre-hardening)
ansible-playbook \
  -i ansible-hardening/inventory/hosts \
  --extra-vars "target=myserver" -u admin -b \
  ansible-hardening/playbooks/1_execute_baseline_before.yml
# → report saved to ansible-hardening/reports/before/myserver/report.json
```

---

### Step 2: Open the dashboard

**Linux / macOS:**
```bash
xdg-open dashboard/index.html         # Linux
open dashboard/index.html             # macOS
```

**WSL2 (Windows Subsystem for Linux):**
```bash
# Option A: open via Windows Explorer
explorer.exe dashboard/index.html

# Option B: get the Windows path and paste into browser
wslpath -w $(pwd)/dashboard/index.html
# Output: \\wsl$\Ubuntu\...\dashboard\index.html
# Paste that path into Chrome / Edge address bar
```

**Any platform, serve locally:**
```bash
python3 -m http.server 8080 --directory dashboard/
# Then open http://localhost:8080 in your browser
```

---

### Step 3: Load reports

1. Click **Load Reports** (top right) or drag & drop `.json` files onto the drop zone
2. The dashboard groups reports by `host` field, load reports from multiple hosts at once
3. For before/after comparison: load two reports for the same host, the dashboard detects them automatically by date and shows the score delta

**Where to find reports after an Ansible pipeline run:**
```
ansible-hardening/reports/before/<hostname>/report.json   ← pre-hardening
ansible-hardening/reports/after/<hostname>/report.json    ← post-hardening
```

---

### Step 4: Explore

- **Fleet view**: all hosts on one screen, worst score first
- **Click a host card**: opens the detail panel with all 109 checks
- **Filter** by FAIL / WARN / PASS to focus on what matters
- **Ansible remediation** block shows the exact command to remediate FAIL/WARN items
- **Export PDF**: click the button top right, then use your browser's print dialog

> Full reference: [`dashboard/README.md`](../dashboard/README.md)

---

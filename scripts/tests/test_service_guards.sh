#!/usr/bin/env bash
# Every service task must survive check mode on a host that does not have the
# unit yet.
#
# `aartool plan` runs the hardening playbook with --check. A preview installs
# nothing, so a role that installs a package and then starts its service hits a
# unit that is not there:
#
#   TASK [linux_ssh_hardening_ubuntu : Enable and start ssh service]
#   fatal: [localhost]: FAILED! => "Could not find the requested service ssh"
#
# That is a preview failing on exactly the host the role exists for, and it was
# reported twice by users before this test existed: once for ufw, once for ssh.
# There were 40 unguarded service tasks at the time.
#
# A service task is acceptable if any of these is true:
#   - it names no service (systemd daemon-reload cannot fail this way)
#   - its name is templated AND it is guarded on ansible_facts.services
#   - it tolerates failure (failed_when: false / ignore_errors)
#   - it carries the unit-existence guard on `aartool_units`
#
# Run: bash scripts/tests/test_service_guards.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

command -v python3 >/dev/null || { echo "python3 required"; exit 1; }

python3 - <<'PY'
import glob, io, yaml, sys

MODS = {"ansible.builtin.service", "ansible.builtin.systemd",
        "ansible.builtin.systemd_service", "service", "systemd"}
PASS = FAIL = 0
files = sorted(glob.glob("../ansible-hardening/roles/*/tasks/*.yml") +
               glob.glob("../ansible-hardening/roles/*/handlers/*.yml"))
if not files:
    print("FAIL  no role files found; the glob is wrong and this test proves nothing")
    sys.exit(1)

for f in files:
    try:
        doc = yaml.safe_load(io.open(f, encoding="utf-8"))
    except Exception as e:
        print(f"FAIL  {f}: {e}")
        FAIL += 1
        continue
    if not isinstance(doc, list):
        continue
    for t in doc:
        if not isinstance(t, dict):
            continue
        mod = next((k for k in t if k in MODS), None)
        if not mod:
            continue
        args = t[mod] if isinstance(t[mod], dict) else {}
        svc = str(args.get("name", "")).strip()
        when = str(t.get("when", ""))
        soft = t.get("failed_when") is False or bool(t.get("ignore_errors"))
        name = str(t.get("name", "?"))[:48]
        role = f.split("/")[3]

        if not svc:                                   # daemon-reload
            PASS += 1
        elif soft:
            PASS += 1
        elif "{{" in svc:
            if "ansible_facts.services" in when or "aartool_units" in when:
                PASS += 1
            else:
                print(f"FAIL  {role}: '{name}' has a templated service name and no "
                      f"existence guard")
                FAIL += 1
        elif "aartool_units" in when:
            PASS += 1
        else:
            print(f"FAIL  {role}: '{name}' manages '{svc}' with no guard; a preview "
                  f"on a host without that unit will fail")
            FAIL += 1

print(f"\n{PASS} passed, {FAIL} failed")
sys.exit(1 if FAIL else 0)
PY

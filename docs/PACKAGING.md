# Packaging

How the `.deb` and the `.rpm` are built, what they put where, and why.

For installing aartool, see the Install section of the [README](../README.md).

## Building

```
packaging/build.sh [OUTDIR]     # default: packaging/dist
```

nfpm runs in a container, so this needs no packaging toolchain on the machine
and behaves the same here as in CI. One config, `packaging/nfpm.yaml`, produces
both formats. There is nothing to compile: a hand-maintained `debian/rules` and
a `.spec` describing the same noarch payload would drift apart, the way every
other pair of literals in this repository eventually has.

The version comes from `AARTOOL_VERSION` in `scripts/aartool-src/main.sh`, so a
package cannot report a version the tool does not. `test_versions.sh` fails if
anyone types a literal into `nfpm.yaml` instead.

## The payload comes from git, not from your working copy

`build.sh` stages with `git archive HEAD`. This is a safety property rather than
tidiness:

`ansible-hardening/inventory/hosts` is gitignored **because it names real
machines**, and it exists in most working copies. Staging from the working tree
would publish it to everyone who runs `apt install aartool`. `git archive`
cannot see it, and the build additionally refuses to run if that file ever
turns up in the payload.

Build scaffolding, test scaffolding and the bundle sources are pruned. The
sources stay on GitHub, which is where the GPL points people.

## Layout

| Path | What |
|---|---|
| `/usr/bin/aartool` | **symlink** to `/usr/share/aartool/scripts/aartool` |
| `/usr/share/aartool/` | the payload: scripts, `ansible-hardening/`, dashboard |
| `/usr/share/aartool/.packaged` | marker: tells aartool it was installed from a package |
| `/etc/aartool/inventory` | your inventory. Not shipped, see below |
| `/usr/share/doc/aartool/` | README, docs, LICENSE |

### Why /usr/bin/aartool is a symlink

aartool finds the playbooks, the baseline script and the dashboard by walking up
from its own file until it sees `ansible-hardening/`. `resolve_paths` follows
symlinks first, so the walk starts in `/usr/share/aartool` where those live.

A **copy** in `/usr/bin` has nothing above it but `/usr` and `/`. It builds, it
installs, it passes any check that only reads the file list, and then every
command fails on first use. This is the same reason `aartool install` symlinks
rather than copies, and `packaging/tests/install-test.sh` asserts it on both
distributions.

### Why the inventory lives in /etc

Everything under `/usr/share` belongs to the package manager and is replaced
wholesale on upgrade. An inventory written there would be destroyed by the next
`apt upgrade` without a word. The `.packaged` marker sends `resolve_paths` to
`/etc/aartool/inventory` instead; a git checkout is unaffected and still uses
`ansible-hardening/inventory/hosts`.

The inventory is **deliberately not shipped**. An inventory that arrives already
populated is one somebody runs `apply` against by accident, and the dangerous
mistake with `apply` has always been the wrong target rather than the wrong
intent. Absent, aartool prints the same copy-the-example message it prints for a
fresh clone.

## The keyring has to be world readable

apt verifies signatures as the unprivileged `_apt` user, not as root. The
documented install therefore ends with:

```bash
sudo chmod a+r /etc/apt/keyrings/aartool.asc
```

Without it, `curl ... | sudo tee` creates the file with the invoking user's
umask. On a machine set to `umask 027` that is mode 0640, `_apt` cannot read it,
and apt reports:

```
Err:6 https://pkgs.cyberaar.io/deb stable InRelease
  Unknown error executing apt-key
E: The repository ... is not signed.
```

which names neither permissions nor the file, and reads like a signing problem
on our side rather than a local one.

This was shipped and hit a real user. It survived testing because the container
running the test was root with `umask 022`, so `tee` happened to produce 0644
and the missing `chmod` never mattered. The install test now runs under
`umask 027` for exactly this reason. It is the second time this machine's umask
has produced a defect: the first packages built were 0640 throughout, readable
only by root.

## Ansible is a weak dependency

`Recommends:` on Debian, `Suggests:` on RPM. Not `Depends:`.

`inspect`, `advise`, `explain`, `surface`, `report` and `diff` never invoke
Ansible. A tool whose claim is that it runs on a constrained machine should not
pull in the Ansible stack before it will tell you what is wrong with your
`sshd_config`. `plan` and `apply` check for it themselves and say so, and
`aartool doctor` reports it.

Note that `apt` installs Recommends by default and `dnf` does not install
Suggests, so a Debian user gets Ansible unless they ask not to, and a Fedora or
RHEL user installs it when they need `plan` and `apply`. That asymmetry is the
distributions' convention, not ours.

## Testing

```
packaging/tests/install-test.sh
```

Installs both packages in `debian:12` and `rockylinux:9` and uses them: version,
help, `explain --list`, `explain SSH-01`, the inventory path, and a real
`inspect` run to completion.

The probes run as a **non-root user** wherever they can. The first build of this
package shipped mode `0640` throughout, so root could run it and nobody else
could even read it, and root-only testing would have found nothing.

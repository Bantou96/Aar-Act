# Security policy

## Reporting a vulnerability

Report privately, not in a public issue.

- **Preferred:** [GitHub private vulnerability reporting](https://github.com/cyberaar/aartool/security/advisories/new)
- **Email:** security@cyberaar.io

The same address is published at
[cyberaar.io/.well-known/security.txt](https://cyberaar.io/.well-known/security.txt),
and the disclosure policy is at
[cyberaar.io/signaler-vulnerabilite](https://cyberaar.io/signaler-vulnerabilite).

Please include the aartool version (`aartool --version`), the operating system,
and what an attacker gets. A proof of concept helps, but a clear description of
the path is enough to start.

We aim to acknowledge within 72 hours and to ship a fix or a documented
mitigation within 30 days. You will be credited in the release notes unless you
prefer otherwise.

## Supported versions

The latest release on the `main` branch. Packages served from
`pkgs.cyberaar.io` track it, so `apt upgrade` and `dnf upgrade` are the fix
path.

## Scope

In scope: anything in this repository, the published `.deb` and `.rpm`, and the
signing and distribution of both.

What we consider most serious, given what this tool does:

- Command injection through a hostname, inventory entry, or check output, since
  much of it is shell that runs as root over SSH.
- Anything that makes `inspect`, `plan`, `diff` or `surface` modify a host.
  These are documented as read-only and are relied on that way.
- `--anonymise` or `--redact` leaving identifying data in a report that is
  meant to be shareable outside the estate it came from.
- Report HTML that executes attacker-controlled content from a scanned host,
  since reports are opened by someone other than the person who ran the audit.

Out of scope: findings that a hardening check does not cover a control you
expected. Those are feature requests, so open an issue.

## Verifying what you downloaded

Release assets are published with `SHA256SUMS`, and both packages and the
repository metadata are signed. For a tool that rewrites `sshd_config` and PAM,
checking the download is not ceremony:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

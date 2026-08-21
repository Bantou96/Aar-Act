# Role: linux_crypto_policies_rhel9

## Purpose

Configures system-wide cryptographic policies on RHEL 9 family systems to enforce strong algorithm selection across all crypto libraries (OpenSSL, GnuTLS, NSS, Kerberos):
- Installs `crypto-policies` and `crypto-policies-scripts`
- Sets the system policy (`FUTURE` by default, stronger than `DEFAULT`)
- Optionally applies custom sub-policy modules (e.g. `no-sha1`, `no-3des`)
- Re-applies the policy so all services pick up the change immediately

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.10 Ensure system-wide cryptographic policies are not set to legacy
- 1.11 Ensure system-wide cryptographic policies are followed (SSH)

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_crypto_policies_policy` | `FUTURE` | Policy to apply: `DEFAULT` / `FUTURE` / `FIPS` / `LEGACY` |
| `linux_crypto_policies_subpolicies` | `[no-sha1]` | Sub-policy modules to create and apply |
| `linux_crypto_policies_reload` | `true` | Run `update-crypto-policies --set` to apply immediately |
| `linux_crypto_policies_disabled` | `false` | Set `true` to skip this role entirely |

### Crypto policy comparison

| Policy | Strength | Use case |
|---|---|---|
| `LEGACY` | Weak | Compatibility with very old systems: **not CIS compliant** |
| `DEFAULT` | Moderate | RHEL default: CIS Level 1 minimum |
| `FUTURE` | Strong | CIS Level 2 recommendation: disables SHA-1, 3DES, RC4 |
| `FIPS` | FIPS 140 | Government/regulated environments requiring FIPS validation |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

linux_crypto_policies_policy: "FUTURE"

# Add no-3des in addition to no-sha1 for very strict environments
linux_crypto_policies_subpolicies:
  - "no-sha1"
  - "no-3des"
```

## Important Notes

Setting `FUTURE` or `FIPS` may break connections to legacy systems (old SSH clients, TLS 1.0/1.1 servers, SHA-1 certificates). Test in dry-run mode first and verify SSH connectivity before applying.

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Mechanism | `update-crypto-policies` (system-wide) | Manual OpenSSL + GnuTLS config (`/etc/ssl/openssl.cnf`, `/etc/gnutls/config`) |
| Package | `crypto-policies`, `crypto-policies-scripts` | No equivalent package |
| FIPS support | Native via `FIPS` policy + kernel | Requires Ubuntu Pro subscription |
| Scope | All crypto libraries | OpenSSL + GnuTLS only |
| Variables | RHEL-specific | Ubuntu-specific (different approach) |

The Ubuntu counterpart role (`linux_crypto_policies_ubuntu`) directly edits OpenSSL and GnuTLS configuration files rather than using a unified policy engine.

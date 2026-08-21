# linux_crypto_policies_ubuntu

## Purpose
Configures system-wide cryptographic policies for OpenSSL and GnuTLS to enforce strong TLS settings and disable weak ciphers and protocols.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.10, Ensure system-wide crypto policy is not legacy

## Key Variables
```yaml
linux_crypto_policies_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.

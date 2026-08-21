# Running this suite on a container host

Most Linux servers now run containers. A hardening benchmark describes a Linux
host, not a Linux host running Docker, so several controls in this suite conflict
with a container runtime.

Everything on this page was found by running these roles on a production estate,
not by reading the benchmark. Each item lists the symptom first, because that is
what you will see.

The collection already exposes every variable named here. What was missing was
knowing when to set them.

---

## IP forwarding

**Symptom.** Containers lose network access. Often not immediately: the value is
written to persistent configuration while the running kernel keeps the old
setting, so the outage arrives at the next reboot, possibly weeks after the
change that caused it.

**Cause.** Docker's bridge networking requires the host to forward packets
between the physical interface and the virtual ones. CIS 3.1.1 and 3.1.2 ask for
forwarding to be disabled on a host that is not a router. Both are correct in
isolation. On a container host, applying the control does not harden the machine,
it switches off the service the machine provides.

**Setting.**

```yaml
# All nodes run containers, so the runtime manages forwarding.
linux_kernel_disable_ip_forward: false
linux_ip_forwarding_ubuntu_disabled: true
```

Two variables because two roles touch the same sysctl: `linux_kernel_hardening_*`
sets it as part of a wider network block, and `linux_ip_forwarding_*` owns it
directly. Setting only one leaves the other to undo your intent.

**Verify what survives a reboot, not what is in the file.** A written value and
an applied value are different things, and only the first is visible in a diff.

---

## Application confinement

**Symptom.** Containers fail to start, or start with the wrong profile applied.

**Cause.** The container runtime ships and manages its own AppArmor profiles.
The system-wide role does not know about them.

**Setting.**

```yaml
linux_apparmor_ubuntu_disabled: true
```

Set it per group, on the hosts that actually run containers, rather than
estate-wide. The control is not being removed: it moves to the mechanism that
understands containers. That distinction matters when an auditor asks.

---

## Firewall rules and the DOCKER-USER chain

**Symptom.** Custom forwarding rules appear in `iptables -L` and have no effect.

**Cause.** Docker sets the `FORWARD` chain policy to `DROP` and inserts a jump to
its own chain, `DOCKER-USER`, at the top. Rules written directly into `FORWARD`
are evaluated too late or never reached.

**What to do.** Put custom forwarding rules in `DOCKER-USER`, never in `FORWARD`.
Order inside that chain matters too: allow `ESTABLISHED,RELATED` first, because
return traffic carries the remote host's source address rather than your private
range, so a source-based rule will miss it and the `DROP` policy will discard it.
Connections then hang instead of being refused, which is considerably slower to
diagnose.

If containers reach a bridge network the firewall role does not know about, its
subnet needs an explicit allowance. A bridge that is absent from the rule set
produces silent drops that look like an application fault.

---

## File integrity monitoring

**Symptom.** None. This one is a duplication rather than a failure.

**Cause.** The benchmark mandates a file integrity tool. An estate that already
runs a security agent doing file integrity monitoring gains a second scanner
covering the same ground, with its own database to maintain and its own alerts
going to a different place.

**Setting.**

```yaml
linux_aide_disabled: true
```

This is a **compensating control**, not a waiver. It commits you to the agent
actually performing the check and to its findings being seen. Record it as such.
If the agent goes away, this exception has to go with it.

---

## Controls that do not apply to a cloud instance

**Bootloader password.** There is no console access at boot on a provider's
virtual machine, so the threat model the control addresses does not exist.

```yaml
linux_bootloader_password_ubuntu_disabled: true
```

**IPv6.** The benchmark suggests disabling it. If your provider's network uses
IPv6, disabling it degrades connectivity with no identifiable security benefit.

```yaml
linux_ipv6_ubuntu_disabled: false
```

---

## SSH agents and lockout

Not a container issue, but the most common way to lose access to a freshly
hardened estate.

**Symptom.** `Too many authentication failures`, then nothing at all, across
every node at once, including the bastion.

**Cause.** `MaxAuthTries` counts each key an SSH agent offers. An agent holding
more keys than the limit exhausts the quota before the correct key is presented.
Each closed connection counts as a failed login to fail2ban, and a playbook run
with several forks opens simultaneous connections to every host from one address,
so they all ban it together.

**What to do.** `IdentitiesOnly=yes`, **on every hop**, including inside any
`ProxyCommand`. Fixing only the final connection leaves the bastion to be banned,
which produces the same outage with one fewer component available to diagnose it.

Raising `MaxAuthTries` or lengthening `findtime` treats the symptom and weakens
the control. The server is not wrong.

---

## Recording exceptions

Every setting above is a deviation from the benchmark. The deviation is not the
problem; an undocumented one is.

Keep the reason next to the variable, where the estate is configured, rather than
in a separate document that will drift:

```yaml
linux_kernel_disable_ip_forward: false   # all nodes run containers
linux_aide_disabled: true                # integrity handled by the SOC agent
```

A hardening score counts controls, and counts an inapplicable control the same as
an unexplained one. The useful question is not how many pass, but whether the
ones that fail are all known, reasoned and dated. An estate at 78% documented
line by line is in a better position than one at 92% whose gap nobody can
explain.

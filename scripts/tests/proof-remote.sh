#!/usr/bin/env bash
# End-to-end proof of the remote path, against real hosts over real SSH.
#
# The unit tests cover argument handling and output shape. They cannot cover the
# thing that has actually broken twice: the transport. Both failures looked like
# success from inside the tool.
#
#   - scp in OpenSSH 9 speaks SFTP, and a hardened host often has no sftp
#     subsystem. The copy failed, the run failed, the fleet summary said
#     "1 succeeded".
#   - `--ssh-opt '-J user@bastion'` does not carry --ssh-key or the connection
#     options onto the jump hop, so on an estate with a dedicated key it fails
#     on hop one with a host key error that never names the bastion.
#
# This script stands up two containers on a private Docker network: a bastion
# with a published port, and a target with none. The image deliberately has the
# sftp subsystem removed, so scp CANNOT work against it, and a weakened
# sshd_config so the audit has real findings. It then runs the whole loop:
#
#   inspect direct -> inspect through the bastion -> advise -> harden by hand
#   -> re-inspect -> diff both directions, asserting the exit codes
#
# Requires docker. Not wired into CI: it pulls an image and builds. Run it
# before releasing anything that touches scripts/src/lib/remote.sh.
#
# Run: bash scripts/tests/proof-remote.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
AARTOOL="./aartool"
WORK=$(mktemp -d -t aar-proof-XXXXXX)
NET=aar-proof-net
PASS=0 FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$*"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

cleanup() {
  docker rm -f aar-bastion aar-target >/dev/null 2>&1
  docker network rm "$NET" >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

command -v docker >/dev/null || { echo "docker is required"; exit 1; }
docker info >/dev/null 2>&1  || { echo "docker is not running"; exit 1; }

step "Building two hosts: a bastion, and a private target with no sftp subsystem"
ssh-keygen -q -t ed25519 -N '' -f "$WORK/id_proof" -C aar-proof
cat > "$WORK/Dockerfile" <<'DOCKER'
FROM ubuntu:24.04
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      openssh-server sudo python3 iproute2 procps net-tools ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash admin && \
    echo 'admin ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/admin && \
    chmod 440 /etc/sudoers.d/admin && mkdir -p /home/admin/.ssh /run/sshd
COPY id_proof.pub /home/admin/.ssh/authorized_keys
RUN chown -R admin:admin /home/admin/.ssh && chmod 700 /home/admin/.ssh && \
    chmod 600 /home/admin/.ssh/authorized_keys
# Weakened on purpose, so the audit has something real to find. The Subsystem
# line is removed on purpose too: that is the host shape scp cannot reach.
RUN sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*X11Forwarding.*/X11Forwarding yes/'     /etc/ssh/sshd_config && \
    sed -i '/^Subsystem[[:space:]]*sftp/d'               /etc/ssh/sshd_config && \
    echo 'MaxAuthTries 6' >> /etc/ssh/sshd_config
CMD ["/usr/sbin/sshd","-D","-e"]
DOCKER
docker build -q -t aar-proof:latest "$WORK" >/dev/null || { echo "build failed"; exit 1; }
docker network create "$NET" >/dev/null 2>&1
docker rm -f aar-bastion aar-target >/dev/null 2>&1
docker run -d --name aar-bastion --network "$NET" -p 127.0.0.1:2222:22 aar-proof:latest >/dev/null
docker run -d --name aar-target  --network "$NET" aar-proof:latest >/dev/null
sleep 3
TIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' aar-target)
SSHK="$WORK/id_proof"
COMMON=(--user admin --ssh-key "$SSHK"
        --ssh-opt '-o' --ssh-opt 'StrictHostKeyChecking=no'
        --ssh-opt '-o' --ssh-opt "UserKnownHostsFile=$WORK/known_hosts")

step "scp must be impossible against this host, or the proof proves nothing"
echo probe > "$WORK/probe"
if scp -q -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o IdentitiesOnly=yes -i "$SSHK" -P 2222 "$WORK/probe" admin@127.0.0.1:/tmp/probe 2>/dev/null; then
  bad "scp succeeded, so this host is not the shape we need to test"
else
  ok "scp fails on the target, as a hardened host does"
fi

step "Direct audit over the ssh-cat transport"
if $AARTOOL inspect --host 127.0.0.1 "${COMMON[@]}" \
     --ssh-opt '-p' --ssh-opt '2222' -o "$WORK/direct" >/dev/null 2>&1; then
  ok "inspect completed where scp cannot"
else
  bad "direct inspect failed"
fi
D=$(ls -t "$WORK"/direct/*.json 2>/dev/null | head -1)
[[ -n "$D" ]] && ok "a JSON report was written" || bad "no JSON report"
n=$(grep -o '"id":"' "$D" 2>/dev/null | wc -l)
[[ "$n" -gt 100 ]] && ok "$n checks in the report" || bad "only $n checks in the report"

step "Audit a private host through the bastion, with --jump"
if $AARTOOL inspect --host "$TIP" "${COMMON[@]}" \
     --jump 'admin@127.0.0.1:2222' -o "$WORK/before" >/dev/null 2>&1; then
  ok "--jump reached a host with no published port"
else
  bad "--jump failed"
fi
B=$(ls -t "$WORK"/before/*.json 2>/dev/null | head -1)

step "advise turns it into a plan"
A_OUT=$($AARTOOL advise "$B" --target aar-target --user admin 2>&1)
grep -q 'Wave 1' <<<"$A_OUT"                  && ok "advise ordered by reachability"      || bad "no waves"
grep -q 'Decide before you apply' <<<"$A_OUT" && ok "advise separated the costly changes" || bad "no decision list"
grep -q 'SSH-01' <<<"$A_OUT"                  && ok "advise surfaced the root login"      || bad "SSH-01 missing"

step "Fix three things on the target, then re-audit through the bastion"
docker exec aar-target bash -c \
  "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/;
           s/^#*X11Forwarding.*/X11Forwarding no/;
           s/^MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config && kill -HUP 1" >/dev/null 2>&1
sleep 2
$AARTOOL inspect --host "$TIP" "${COMMON[@]}" \
  --jump 'admin@127.0.0.1:2222' -o "$WORK/after" >/dev/null 2>&1
AF=$(ls -t "$WORK"/after/*.json 2>/dev/null | head -1)

step "diff, in both directions, with the exit codes the documentation promises"
OUT=$($AARTOOL diff "$B" "$AF" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "improvement exits 0" || bad "improvement exited $rc, want 0"
grep -q 'SSH-01' <<<"$OUT" && ok "diff named the check that improved" || bad "SSH-01 not in the diff"

$AARTOOL diff "$AF" "$B" >/dev/null 2>&1; rc=$?
[[ $rc -eq 1 ]] && ok "regression exits 1" || bad "regression exited $rc, want 1"

$AARTOOL diff "$D" "$AF" >/dev/null 2>&1; rc=$?
[[ $rc -eq 2 ]] && ok "two different hosts exits 2" || bad "cross-host diff exited $rc, want 2"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

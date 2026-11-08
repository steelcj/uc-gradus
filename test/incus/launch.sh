#!/bin/sh
# Creates a throwaway Debian 13 instance on the local Incus host that looks like
# a freshly delivered Ex2 VPS: 1 vCPU, 1 GiB, root reachable over SSH with the
# gradus-raw-initial-id_ed25519 key (as if injected by the provider panel), nothing else set up.
# Then snapshots it as "fresh" so every rehearsal can start from the same point.
#
# Usage: test/incus/launch.sh [container|vm]
# Environment overrides: EX2_TEST_NAME, EX2_TEST_IMAGE, EX2_INITIAL_PUB
set -eu

MODE="${1:-container}"
NAME="${EX2_TEST_NAME:-ex2-test}"
IMAGE="${EX2_TEST_IMAGE:-images:debian/13}"
INITIAL_PUB="${EX2_INITIAL_PUB:-$HOME/.ssh/gradus-raw-initial-id_ed25519.pub}"
HERE=$(cd "$(dirname "$0")" && pwd)

case "$MODE" in
  container|vm) ;;
  *) echo "Usage: $0 [container|vm]" >&2; exit 2 ;;
esac

[ -r "$INITIAL_PUB" ] || { echo "Missing $INITIAL_PUB. Create it first (docs/initial-setup.md, Before you start)." >&2; exit 1; }

if incus info "$NAME" >/dev/null 2>&1; then
  echo "$NAME already exists." >&2
  echo "  Start over:  incus snapshot restore $NAME fresh" >&2
  echo "  Remove it:   incus delete --force $NAME" >&2
  exit 1
fi

if [ "$MODE" = vm ]; then
  incus launch "$IMAGE" "$NAME" --vm -c limits.cpu=1 -c limits.memory=1GiB -d root,size=25GiB
else
  incus launch "$IMAGE" "$NAME" -c limits.cpu=1 -c limits.memory=1GiB
fi

echo "Waiting for $NAME to boot..."
i=0
# "degraded" is normal in containers (a unit or two that only make sense on hardware).
until incus exec "$NAME" -- sh -c 'systemctl is-system-running --wait >/dev/null 2>&1
    case "$(systemctl is-system-running)" in running|degraded) exit 0;; *) exit 1;; esac' 2>/dev/null; do
  i=$((i + 1)); [ "$i" -gt 60 ] && { echo "Timed out waiting for $NAME." >&2; exit 1; }
  sleep 3
done

ip4=""
i=0
while [ -z "$ip4" ]; do
  ip4=$(incus list "$NAME" -c 4 -f csv | awk '{print $1; exit}')
  i=$((i + 1)); [ "$i" -gt 40 ] && { echo "No IPv4 address on $NAME." >&2; exit 1; }
  [ -z "$ip4" ] && sleep 2
done
ip6=$(incus list "$NAME" -c 6 -f csv | awk '{print $1; exit}')

# What a provider image already has: an SSH server and root's injected key.
incus exec "$NAME" -- sh -c 'export DEBIAN_FRONTEND=noninteractive
  apt-get update -q && apt-get install -y -q --no-install-recommends openssh-server'
incus exec "$NAME" -- install -d -m 0700 -o root -g root /root/.ssh
incus file push "$INITIAL_PUB" "$NAME/root/.ssh/authorized_keys" --mode 0600 --uid 0 --gid 0

# The host's own address on the Incus bridge goes on the sshguard whitelist,
# because the verification step deliberately fails logins.
bridge=$(incus profile device get default eth0 network 2>/dev/null || echo incusbr0)
host_ip=$(incus network get "$bridge" ipv4.address 2>/dev/null | cut -d/ -f1)

cat > "$HERE/inventory.ini" <<EOF
# Written by test/incus/launch.sh for instance $NAME ($MODE).
[web]
$NAME ansible_host=$ip4 sshguard_whitelist='["$host_ip"]'
EOF

# Every relaunch has new host keys on a possibly reused address.
ssh-keygen -R "$ip4" >/dev/null 2>&1 || true
[ -n "$ip6" ] && { ssh-keygen -R "$ip6" >/dev/null 2>&1 || true; }

incus snapshot create "$NAME" fresh

cat <<EOF

$NAME is up as a fresh "VPS" ($MODE).
  IPv4: $ip4
  IPv6: ${ip6:-none}
  Console equivalent: incus exec $NAME -- bash$( [ "$MODE" = vm ] && printf '   (or: incus console %s)' "$NAME" )
  Inventory: test/incus/inventory.ini
  Snapshot: fresh   (start over with: incus snapshot restore $NAME fresh)

Next: follow docs/initial-setup.md from "As root: create the initial user",
using ssh -i ~/.ssh/gradus-raw-initial-id_ed25519 root@$ip4
EOF

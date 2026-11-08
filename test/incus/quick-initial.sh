#!/bin/sh
# Shortcut for repeat test runs: does the manual root and initial steps of
# docs/initial-setup.md through `incus exec`, so you can go straight to
# bootstrap.yml. Rehearse the real manual steps at least once; this only
# saves time on later loops.
#
# Usage: test/incus/quick-initial.sh
# Asks for the initial user's password (needed for sudo, so for -K).
set -eu

NAME="${EX2_TEST_NAME:-ex2-test}"
INITIAL_PUB="${EX2_INITIAL_PUB:-$HOME/.ssh/gradus-raw-initial-id_ed25519.pub}"

printf 'Password for initial (used for sudo): '
stty -echo; read -r pw; stty echo; echo
[ -n "$pw" ] || { echo "Empty password." >&2; exit 1; }

incus exec "$NAME" -- sh -c 'export DEBIAN_FRONTEND=noninteractive
  apt-get update -q && apt-get -y -q full-upgrade
  apt-get install -y -q --no-install-recommends sudo rsync python3
  hostnamectl set-hostname web1 2>/dev/null || hostname web1
  id initial >/dev/null 2>&1 || useradd --create-home --shell /bin/bash --groups sudo initial
  install -d -m 0700 -o initial -g initial /home/initial/.ssh'

printf 'initial:%s\n' "$pw" | incus exec "$NAME" -- chpasswd
incus file push "$INITIAL_PUB" "$NAME/home/initial/.ssh/authorized_keys" --mode 0600 --uid 0 --gid 0
incus exec "$NAME" -- chown initial:initial /home/initial/.ssh/authorized_keys

incus exec "$NAME" -- sh -c 'passwd --lock root
cat > /etc/ssh/sshd_config.d/10-hardening.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
EOF
sshd -t && systemctl restart ssh'

echo "Done. Next, from ansible/:"
echo "  ansible-playbook -i ../test/incus/inventory.ini bootstrap.yml -u initial -K"

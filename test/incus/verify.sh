#!/bin/sh
# Checks the finished server from the outside, the way the internet sees it.
# Run after base.yml. Works against the Incus test instance or the real VPS.
#
# Usage: test/incus/verify.sh [ipv4] [ipv6]
# With no arguments, reads the address from test/incus/inventory.ini.
# Uses ~/.ssh/gradus-raw-initial-id_ed25519 and gradus-dev-{admin,deploy}-id_ed25519. nmap and ssh-audit are optional.
#
# Several checks are meant to fail logins. Run this from a whitelisted address
# (launch.sh whitelists the Incus host), or sshguard will block you.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
IP4="${1:-$(sed -n 's/.*ansible_host=\([^ ]*\).*/\1/p' "$HERE/inventory.ini" 2>/dev/null | head -1)}"
IP6="${2:-}"
[ -n "$IP4" ] || { echo "Usage: $0 <ipv4> [ipv6]" >&2; exit 2; }

KEYS="$HOME/.ssh"
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"
pass=0; fail=0

ok()  { pass=$((pass + 1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }
expect_success() { desc=$1; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi; }
expect_failure() { desc=$1; shift; if "$@" >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi; }
# Passes only when sshd itself refuses the key, not when the host is unreachable.
expect_denied() { desc=$1; shift; if "$@" 2>&1 | grep -q 'Permission denied'; then ok "$desc"; else bad "$desc"; fi; }

echo "Checking $IP4${IP6:+ and $IP6}"

# Without a working admin login, every "is refused" check below would pass for the wrong reason.
if ! $SSH -i "$KEYS/gradus-dev-admin-id_ed25519" "admin@$IP4" true >/dev/null 2>&1; then
  echo "FAIL  admin cannot log in to $IP4; stopping, the remaining checks would be meaningless."
  exit 1
fi
ok "admin logs in with its key"

# Accounts and SSH
expect_denied "root is refused"                       $SSH -i "$KEYS/gradus-raw-initial-id_ed25519" "root@$IP4" true
expect_denied "initial is refused (removed)"          $SSH -i "$KEYS/gradus-raw-initial-id_ed25519" "initial@$IP4" true
expect_denied "admin key is refused for deploy"       $SSH -i "$KEYS/gradus-dev-admin-id_ed25519" "deploy@$IP4" true

# The deploy key authenticates, but rrsync refuses anything that is not rsync.
if out=$($SSH -i "$KEYS/gradus-dev-deploy-id_ed25519" "deploy@$IP4" id 2>&1); then
  bad "deploy key gets no shell (ran: $out)"
elif printf '%s' "$out" | grep -q 'Permission denied'; then
  bad "deploy key gets no shell (key was refused outright, check its authorized_keys)"
else
  ok "deploy key gets no shell"
fi

if $SSH -o PubkeyAuthentication=no "admin@$IP4" true 2>&1 | grep -q 'Permission denied (publickey)'; then
  ok "server offers publickey only, no password"
else
  bad "server offers publickey only, no password"
fi

# Deploy path: rsync works, confined to /srv/sites, explicit modes
tmp=$(mktemp -d); echo "verify $(date -u +%FT%TZ)" > "$tmp/index.html"
expect_success "deploy can rsync into the sites root" \
  rsync -rlt --chmod=D755,F644 -e "$SSH -i $KEYS/gradus-dev-deploy-id_ed25519" "$tmp/" "deploy@$IP4:.verify/"
expect_success "deploy can list what it pushed" \
  rsync --list-only -e "$SSH -i $KEYS/gradus-dev-deploy-id_ed25519" "deploy@$IP4:.verify/index.html"
expect_failure "deploy cannot read outside the sites root" \
  rsync --list-only -e "$SSH -i $KEYS/gradus-dev-deploy-id_ed25519" "deploy@$IP4:../../etc/passwd"
rm -r "$tmp"

# Web
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$IP4/" || true)
case "$code" in 2??|3??|404) ok "Caddy answers on port 80 (HTTP $code)";; *) bad "Caddy answers on port 80 (got '$code')";; esac

# Open ports
scan() {
  label=$1; shift
  open=$(nmap -Pn -p- --open "$@" 2>/dev/null | awk '/^[0-9]+\/tcp/ {split($1,a,"/"); printf "%s ", a[1]}')
  extra=$(printf '%s' "$open" | tr ' ' '\n' | grep -vxE '22|80|443|' || true)
  if [ -z "$extra" ]; then ok "$label open TCP ports: ${open:-none} (expected 22 80 443)"; else bad "$label unexpected open TCP ports: $extra"; fi
}
if command -v nmap >/dev/null; then
  scan "IPv4" "$IP4"
  [ -n "$IP6" ] && scan "IPv6" -6 "$IP6"
else
  echo "SKIP  port scan (install nmap)"
fi

# SSH crypto
if command -v ssh-audit >/dev/null; then
  if ssh-audit -l fail "$IP4" >/dev/null 2>&1; then ok "ssh-audit reports no failures"; else bad "ssh-audit reports failures (run: ssh-audit $IP4)"; fi
else
  echo "SKIP  ssh-audit (pipx install ssh-audit)"
fi

echo
echo "$pass passed, $fail failed"
echo "On the server, also run: ssh -t -i $KEYS/gradus-dev-admin-id_ed25519 admin@$IP4 sudo /usr/local/sbin/audit-listeners.sh"
[ "$fail" -eq 0 ]

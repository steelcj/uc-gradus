#!/bin/sh
# Lists every listening socket and exits 1 if anything other than sshd or
# Caddy listens on a non-loopback address. Loopback listeners (such as
# Caddy's admin API on localhost:2019) are reported but allowed, and so are
# DHCP client sockets (udp 68 and 546), which are clients, not services, and
# which the nftables ruleset does not open.
# Usage: sudo audit-listeners.sh
set -eu

command -v ss >/dev/null || { echo "ss not found (install iproute2)" >&2; exit 2; }

ss -Htulpn | awk '
{
    netid = $1; local = $5; proc = $NF
    if (proc ~ /^users:/) {
        name = proc
        sub(/^users:\(\("/, "", name)
        sub(/".*$/, "", name)
    } else name = "(no process info)"
    loopback = (local ~ /^127\./ || local ~ /^\[::1\]/ || local ~ /%lo:/)
    if (name == "sshd" || name == "caddy") status = "ok"
    else if (loopback)                      status = "loopback"
    else if (netid == "udp" && local ~ /:(68|546)$/) status = "dhcp-client"
    else                                   { status = "UNEXPECTED"; bad = 1 }
    printf "%-11s %-4s %-42s %s\n", status, netid, local, name
}
END { exit bad }'

#!/bin/sh
# One-time bootstrap for a fresh Debian 13 server when the provider does not
# accept cloud-init user-data. Run as root, from the provider console or a
# first root SSH session. It does the same job as cloud-init/user-data.yaml:
# creates the admin user with its key, then locks down sshd.
# After this, run ansible/RESOLVE-base.yml as the admin user.
set -eu

ADMIN_USER="admin"
ADMIN_PUBKEY="ssh-ed25519 AAAAREPLACE_ADMIN_PUBLIC_KEY admin@laptop"

case "$ADMIN_PUBKEY" in
  *REPLACE*) echo "Edit ADMIN_PUBKEY first." >&2; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y full-upgrade
apt-get install -y --no-install-recommends sudo python3 rsync openssh-server

if ! id "$ADMIN_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash --groups sudo "$ADMIN_USER"
else
  usermod --append --groups sudo "$ADMIN_USER"
fi

install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
printf '%s\n' "$ADMIN_PUBKEY" > "/home/$ADMIN_USER/.ssh/authorized_keys"
chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh/authorized_keys"
chmod 0600 "/home/$ADMIN_USER/.ssh/authorized_keys"

echo "Set a password for $ADMIN_USER. It is used for sudo and the provider console, never for SSH."
passwd "$ADMIN_USER"

cat > /etc/ssh/sshd_config.d/10-hardening.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
AllowUsers $ADMIN_USER
EOF

sshd -t
passwd --lock root
systemctl restart ssh

echo "Done. Before closing this session, confirm from your laptop:"
echo "  ssh $ADMIN_USER@<server> sudo -v"

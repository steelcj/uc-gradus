> Historical. Superseded by README v0.3.0.

# ex2-base

Version 0.3.3. Changes are listed in `CHANGELOG.md`.

A minimal, secure base for a Debian 13 (trixie) static-site server on an Ex2 Cloud Performance VPS. The server only serves files: sshd and Caddy are the only public listeners, and deploys arrive by rsync over a restricted key.

## How the automation is split

cloud-init does first-boot identity only: hostname, the admin user and its key, and an immediate sshd lockdown. It runs once, so it is the wrong place for anything you will want to change or re-check later.

Ansible does everything else, in two playbooks. `bootstrap.yml` runs once as a temporary `initial` user and creates the permanent users; `base.yml` runs as `admin` from then on. Two roles by Robert de Bock do the generic parts: `robertdebock.bootstrap` makes a bare image ready for Ansible, and `robertdebock.users` manages the permanent users. They are pinned to release tags in `ansible/requirements.yml`. His `openssh`, `firewall`, `ntp` and `umask` roles were checked and not used: the openssh role exposes no cipher or KEX settings, the firewall role targets iptables, ufw or firewalld rather than nftables, the ntp role uses chrony or ntpd rather than timesyncd, and the umask role only edits `~/.bashrc`. The playbooks are idempotent, so re-running them corrects drift, and `base.yml` ends with an audit that fails loudly if sshd settings, AppArmor or the listening sockets are not what this base promises. It needs nothing installed on the server beyond Python, which rrsync needs anyway, and it is provider-neutral, so the same repo rebuilds the server on another host if you ever move.

If Ex2 does not accept cloud-init user-data, there are two manual routes. `en/docs/initial-setup.md` is the step-by-step runbook: a temporary `initial` user shuts root out, sets a `027` umask policy, creates `admin` and `deploy`, and is then deleted. `bootstrap/bootstrap.sh` is the short scripted version, without the `initial` user or the umask policy (the playbook applies the umask policy either way).

## Layout

- `en/docs/initial-setup.md`, the manual first-session runbook
- `en/docs/incus-testing.md`, rehearsing everything on a local Incus container or VM first
- `en/docs/ansible-venv.md`, running Ansible from a versioned virtual environment on the laptop
- `en/docs/process-flowchart.md`, top-down flowcharts of the whole process, from preparing flow to deploying a site
- `tools/make-ansible-venv.sh`, builds that environment from `ansible/controller-requirements.txt`
- `test/incus/`, the rehearsal harness: `launch.sh`, `quick-initial.sh`, `verify.sh` (which also checks the real VPS)
- `cloud-init/user-data.yaml`, first-boot identity, if the provider supports user-data
- `bootstrap/bootstrap.sh`, the same job without cloud-init
- `ansible/requirements.yml`, the pinned roles and collections
- `ansible/bootstrap.yml`, first run as `initial`: bootstrap role, umask policy, users role
- `ansible/base.yml`, every later run as `admin`
- `ansible/tasks/`, the umask policy and deploy key tasks both playbooks share
- `ansible/group_vars/all.yml`, every setting you are expected to change, including the `users` list for the users role
- `ansible/group_vars/web/vault.yml`, the admin password hash, encrypted with ansible-vault (yours to create)
- `ansible/templates/`, sshd drop-in, nftables ruleset, deploy `authorized_keys`, unattended-upgrades, journald
- `ansible/files/audit-listeners.sh`, the `ss -tulpn` check, also installed on the server as `/usr/local/sbin/audit-listeners.sh`

## Order of operations

### Keys

Make two separate keypairs on your laptop. The deploy key can go into CI; the admin key never does.

```sh
ssh-keygen -t ed25519 -f ~/.ssh/gradus-prod-admin-id_ed25519  -C admin@laptop
ssh-keygen -t ed25519 -f ~/.ssh/gradus-prod-deploy-id_ed25519 -C deploy@ci -N ''
```

Put both public keys in `ansible/group_vars/all.yml`, and the admin public key in `cloud-init/user-data.yaml` or `bootstrap/bootstrap.sh`. Generate the admin password hash with `mkpasswd -m yescrypt` (package `whois`) and keep it in `ansible/group_vars/web/vault.yml`, created with `ansible-vault create`; `en/docs/initial-setup.md` has the exact steps. The admin password is used for sudo and the provider console only, never for SSH. It is what gets you in through the console when SSH is broken, so store it in your password manager.

### Rehearse locally

Run the whole procedure against a local Incus instance first, as described in `en/docs/incus-testing.md`. Its troubleshooting section covers the failures met on the first rehearsal.

### Create the server

Choose the Debian 13 image and paste the user-data if the panel offers it. Otherwise follow `en/docs/initial-setup.md`, or for a quicker start open the console and run `bootstrap.sh` as root. Then confirm `ssh -i ~/.ssh/gradus-prod-admin-id_ed25519 admin@<ip> sudo -v` works from the laptop.

### Run the playbooks

From `ansible/`, with the server IP in `inventory.ini` and the Ansible environment active (`en/docs/ansible-venv.md`):

```sh
. ~/.venvs/ansible/current/bin/activate
ansible-galaxy install -r requirements.yml
ansible-playbook bootstrap.yml -u initial -K --ask-vault-pass   # only if you used the initial user
ansible-playbook base.yml -K --ask-vault-pass
```

The first time, keep the provider console open in a browser tab and a second SSH session open. The playbook refuses to run as anyone but the admin user, validates the sshd and nftables files before installing them, and opens the firewall before sshd restarts. On later runs, `--check --diff` previews changes; on a fresh server it reports services as missing because nothing is installed yet, which is expected.

### Verify from outside

`test/incus/verify.sh <ipv4> <ipv6>` runs the account, SSH, deploy, web and port checks in one go. By hand:

```sh
nmap -Pn -p- <ipv4>         # expect 22, 80, 443 open
nmap -6 -Pn -p- <ipv6>      # same over IPv6
nmap -Pn -sU -p 443 <ipv4>  # QUIC
ssh-audit <ip>              # crypto check, from https://github.com/jtesta/ssh-audit
ssh root@<ip>               # must be refused
```

## Deploying

rrsync confines the deploy key to `/srv/sites`, and paths are relative to it:

```sh
rsync -rlt --delete --chmod=D755,F644 -e "ssh -i ~/.ssh/gradus-prod-deploy-id_ed25519" public/ deploy@<ip>:example.org/
```

The explicit `--chmod` matters because of the `027` umask: without it, files can land as `640` and Caddy, running as its own user, serves 403 errors.

That lands in `/srv/sites/example.org/`. To keep old releases, deploy to `example.org/releases/<id>/` and point Caddy at a `current` symlink you switch as admin, or keep it simpler and use `rsync --link-dest` for cheap snapshots. Set `deploy_from` in `group_vars/all.yml` to your IP or the CI runner's IP once you know it.

## Caddy

Caddy comes from trixie-backports. The trixie 2.6.2 package is old and the Debian tracker lists open security issues against it, while backports carries 2.11. Backports packages are added to the unattended-upgrades origins so Caddy updates arrive automatically; backports security support is best-effort compared to the main archive.

The playbook installs and starts Caddy with Debian's default Caddyfile. Write your site blocks in `/etc/caddy/Caddyfile`, for example:

```
example.org {
    root * /srv/sites/example.org
    file_server
    encode zstd gzip
}
```

Caddy also listens on `localhost:2019` for its admin API, which `systemctl reload caddy` uses. The audit reports it as loopback and allows it.

## Design notes

sshguard rather than fail2ban, since it is a small C program with no Python daemon. Debian's default sshguard filter (`-t sshd`) misses OpenSSH 10, which logs failed logins as `sshd-session`, so the playbook switches it to read the `ssh.service` unit. OpenSSH 9.8 and later also have built-in per-source penalties; sshguard adds longer, firewall-level blocks on top.

Where the image uses systemd-resolved, it answers LLMNR on port 5355 on every interface by default. The playbook switches LLMNR and multicast DNS off with a drop-in in `/etc/systemd/resolved.conf.d/`, leaving only resolved's DNS stub on loopback, which the server's own lookups use.

The nftables ruleset replaces only its own table rather than flushing the whole ruleset, so a reload does not wipe sshguard's block lists. ICMPv6 is accepted because IPv6 neighbour discovery and path MTU discovery stop working without it.

The deploy user's `authorized_keys` is root-owned, so even a stolen deploy key cannot change its own restrictions. The deploy shell is `/bin/sh` rather than `nologin` because sshd runs the forced rrsync command through the login shell.

`AllowTcpForwarding no` means no `ssh -L` tunnels as admin either. Relax it in the sshd template if you need them.

`disable_cloud_init` is off by default. Turn it on once you have confirmed the network comes up after a reboot without cloud-init, so a later metadata change on the provider side cannot re-inject keys.

## Open questions for Ex2

Ex2's public pages confirm a real-time console, IPv6, a broad OS catalog with custom ISO support, and backups. They do not say whether these are offered:

- a Debian 13 image, and whether it is a genericcloud or minimal build (custom ISO with the Debian netinst image is the fallback)
- cloud-init user-data at creation time, or only SSH key injection
- snapshots, separate from backups, and their cost and retention
- a provider-level firewall in front of the VM
- reverse DNS for the IPv4 and IPv6 addresses, set in the panel or by ticket
- whether the IPv6 allocation is a single address or a /64

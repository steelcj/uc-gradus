# Initial manual setup

This is the first session on a fresh Ex2 Debian 13 VPS. The manual part is short: root creates a temporary `initial` user, and `initial` shuts root out. From there Ansible does the work. `ansible/bootstrap.yml`, run as `initial`, prepares the host with the `robertdebock.bootstrap` role, sets the umask policy, and creates the permanent `admin` and `deploy` users with the `robertdebock.users` role. `ansible/RESOLVE-base.yml`, run as `admin`, hardens the rest, restricts SSH to `admin` and `deploy`, and deletes `initial`.

The appendix has the same umask and user steps as plain commands, for doing it without Ansible or checking what the playbook did.

Commands marked `laptop$` run on your workstation, `root#` as root on the server, `initial$` as the `initial` user, and `admin$` as `admin`.

## Before you start

### On your local workstation

Make three ed25519 keypairs.

#### initial user

The  `initial` user and key are temporary and get deleted.

#### deploy user

 `deploy` has no passphrase because CI uses it.

#### admin user

 The admin key never goes into CI.

### Creating your key pairs

#### Create or generate your passphrases

Generate the passphrases for the `initial` and `admin` user in your password manager.

The `admin` password is for sudo and the provider console only, never for SSH. If SSH breaks, it is the only way back in.

#### generate your key pairs

From you workstation as a regular user (your "initial" user?) generate your key pairs

```bash
ssh-keygen -t ed25519 -f ~/.ssh/gradus-raw-initial-id_ed25519 -C initial@laptop
ssh-keygen -t ed25519 -f ~/.ssh/gradus-prod-admin-id_ed25519   -C admin@laptop
ssh-keygen -t ed25519 -f ~/.ssh/gradus-prod-deploy-id_ed25519  -C deploy@ci -N ''
```

## Prepare the Ansible

 Ansible runs from a versioned virtual environment, set up as described in `docs/ansible-venv.md`.

### Ansible virtual environment

On you workstation as a regular user setup you Ansible venv

* [Ansible in a versioned virtual environment](./ansible-venv.md)

### Install Ansible

Once your Ansible venv is setup, as a regular user on your workstation, activate it and setup the Ansible requirements

 From `ansible/`, with it active:

```bash
cd ansible
. ~/.venvs/ansible/current/bin/activate
```

Confirm that your prompt now starts with `(ansible)`:

```bash
(ansible) initial@workstation:~/automa-003/ex2-base-v0.3.1/ansible$ 
```

Install the ansible requirements:

```bash
ansible-galaxy install -r RESOLVE-requirements.yml     # roles pinned to release tags on GitHub
```

### Add your public keys to ansible `group_vars/all.yml`

#### Get your public key content

##### admin

```bash
cat ~/.ssh/gradus-prod-admin-id_ed25519.pub
```

Output example:

```bash
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICjFObFmCgI0eJzam5ZNpJvcfdaCbFpy9E21Z5v61Wyh admin@flow
```

##### deploy

```bash
cat ~/.ssh/gradus-prod-deploy-id_ed25519.pub
```

Output example:

```bash
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICs5duGS0SpjeharOkAUC0W+nfmBkFUXFXSnEeN+QG9U deploy@ci
```

### Create a password  hash for the admin user

Again as a local user on your laptop run

```sh
mkpasswd -m yescrypt                 # admin password hash (package whois)
```

Example output:

```bash
$y$j9T$k.rs2L0nJjhJAmRNu5CtE0$CUGlgkyoMbSFNdxWQorRG6VTxhqHVm2hTOIKQ7YBtEC
```

> **Placeholder hash.** The hash above was generated from the password `example` with `mkpasswd -m yescrypt`. It is not used on any server and is safe to publish, so secret scans can ignore it. Your own output will differ, because the salt is random.

### Create an Ansible vault

Next we create an Ansible vault in group_vars/web/vault.yml to hold your admin password. Run as a your workstation user

```bash
mkdir -p group_vars/web && ansible-vault create group_vars/web/vault.yml
```

In the vault editor, add one line, in single quotes because the hash contains `$`:

```yaml
admin_password_hash: '$y$j9T$k.rs2L0nJjhJAmRNu5CtE0$CUGlgkyoMbSFNdxWQorRG6VTxhqHVm2hTOIKQ7YBtEC'
```

> **Placeholder hash.** This is the same `example` placeholder as above. Paste your own hash into the vault, never into the docs.

The public keys are not secret and live in plain `group_vars/all.yml`; the hash goes only in the vault, which overrides the placeholder in `all.yml`.

### Greb IP address

```bash
incus list | grep ex2-test
```

Output example:

```bash
│ ex2-test       │ RUNNING │ 10.119.134.236 (eth0) │ fd42:48:ed9e:b152:1266:6aff:fe4e:6f15 (eth0) │ CONTAINER       │ 1         │
```

Finally, put the server's IPv4 in `inventory.ini` in place of the documentation address `10.119.134.236`.

```bash
nano inventory.ini
```

Entry example:

```ini
web1 ansible_host=10.119.134.236
```

### In the Ex2 panel

- Create the server from the Debian 13 image (fall back to the Debian netinst ISO if there is no image).
- If the panel can inject an SSH key for root, give it `~/.ssh/gradus-raw-initial-id_ed25519.pub`. That avoids typing a key into the console.
- Note the IPv4 and IPv6 addresses, set reverse DNS if the panel offers it, and open the web console in a browser tab. Keep that tab open until the end of this procedure.

## As root: create the initial user

Log in as root, over SSH if a key was injected, otherwise in the console.

From your workstation as a regular user

```sh
ssh -i ~/.ssh/gradus-raw-initial-id_ed25519 root@<ip>
```

Confirm the release and bring the system up to date:

As root run the following commands:

```sh
cat /etc/os-release           # expect VERSION_ID="13"
apt-get update && apt-get -y full-upgrade
apt-get install -y --no-install-recommends sudo rsync python3
hostnamectl set-hostname web1
```

As root create `initial` with sudo rights and a password for sudo:

```sh
root# useradd --create-home --shell /bin/bash --groups sudo initial
root# passwd initial
root# install -d -m 0700 -o initial -g initial /home/initial/.ssh
```

Install its public key. If root's key was injected by the panel, copy it across:

```sh
root# install -m 0600 -o initial -g initial /root/.ssh/authorized_keys /home/initial/.ssh/authorized_keys
```

If you are in the console with no injected key, type or paste the single line from `~/.ssh/gradus-raw-initial-id_ed25519.pub` instead:

```sh
root# printf '%s\n' 'ssh-ed25519 AAAA... initial@laptop' > /home/initial/.ssh/authorized_keys
root# chown initial:initial /home/initial/.ssh/authorized_keys
root# chmod 0600 /home/initial/.ssh/authorized_keys
```

Leave the root session open. In a second terminal, prove `initial` works before root is shut out:

```sh
laptop$ ssh -i ~/.ssh/gradus-raw-initial-id_ed25519 initial@<ip>
initial$ sudo -v
```

## As initial: shut root out

Use the `initial` session from here on. Lock root's password, then stop root and password logins over SSH. The `10-` prefix matters: sshd keeps the first value it reads, and this file sorts before any `50-cloud-init.conf` the image ships.

```sh
initial$ sudo passwd --lock root
initial$ sudo tee /etc/ssh/sshd_config.d/10-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
EOF
initial$ sudo sshd -t && sudo systemctl restart ssh
```

Close the root session, then confirm from the laptop that `ssh root@<ip>` is refused. Your `initial` session stays connected through the restart.

## As initial: run bootstrap.yml

As your regular user

```sh
ansible-playbook bootstrap.yml -u initial -K --ask-vault-pass
```

`-K` asks for the server `initial` user's password, then `--ask-vault-pass` for the vault password. It connects with `~/.ssh/gradus-raw-initial-id_ed25519` (`initial_ssh_key`) and offers no other key.

It does three things, in this order:

- `robertdebock.bootstrap` makes sure `python3`, `sudo`, `gnupg` and `python3-apt` are present, so the rest of Ansible works on a minimal image. The role assumes it connects as root, so `bootstrap.yml` sets `bootstrap_become: true` to make its package install use sudo.
- `tasks/RESOLVE-umask.yml` sets a `027` default umask and `0700` home directories. This has to happen before any permanent user exists, because `useradd` reads these values when it makes their homes. Details are in the appendix.
- `robertdebock.users` creates `admin` (in `sudo`, with only the admin key, and your hashed password) and `deploy` (no password, `/bin/sh`, no groups). `tasks/deploy_access.yml` then writes the deploy key itself, root-owned and restricted to rrsync, and creates `/srv/sites`. The users role is not given the deploy key because it would make `.ssh` owned by `deploy`, which would let a stolen deploy key rewrite its own restrictions.

### What the stricter umask changes

`sudo` keeps the stricter of your umask and its own, so files you create under `/etc` with `sudo tee` or `sudo cp` come out `640 root:root`. That is fine for files only root reads, but a service that runs as its own user cannot read them.

Caddy is the one that matters here

After creating  `/etc/caddy/Caddyfile` 

Run

```bash
sudo chmod 644 /etc/caddy/Caddyfile
```

Playbooks set modes explicitly, so they are not affected.

## Deployment

On the deploy side, files rsynced in without explicit permissions would come out `640` and Caddy would serve 403 errors, so deploy with explicit modes:

```sh
laptop$ rsync -rlt --delete --chmod=D755,F644 -e "ssh -i ~/.ssh/gradus-prod-deploy-id_ed25519" public/ deploy@<ip>:example.org/
```

## Check admin and deploy

Keep the `initial` session open. From a new terminal, prove `admin` works, sudo included:

```sh
ssh -i ~/.ssh/gradus-prod-admin-id_ed25519 admin@<ip>
sudo -v
umask        # expect 0027
sudo stat -c '%a %U:%G %n' /home/admin /home/deploy /home/deploy/.ssh /home/deploy/.ssh/authorized_keys /srv/sites
```

Output examples:

```bash
700 admin:admin /home/admin
700 deploy:deploy /home/deploy
755 root:root /home/deploy/.ssh
644 root:root /home/deploy/.ssh/authorized_keys
755 deploy:deploy /srv/sites
```

* Expect `700` on both homes
*  `755 root:root` and
*  `644 root:root` for the deploy `.ssh` and its key file, and
*  `755 deploy:deploy` on `/srv/sites`.

Prove the deploy key is confined to rsync:

```sh
laptop$ ssh -i ~/.ssh/gradus-prod-deploy-id_ed25519 deploy@10.119.134.236 # must not give a shell
# Below not working
laptop$ rsync -rlt --chmod=D755,F644 -e "ssh -i ~/.ssh/gradus-prod-deploy-id_ed25519" /etc/hostname deploy@<ip>:test/
admin$ ls -l /srv/sites/test/ && sudo rm -r /srv/sites/test
```

## As admin: run RESOLVE-base.yml, which removes initial

Take a snapshot first if Ex2 offers them. Then log out of every `initial` session and run, as `admin`:

```sh
laptop$ ansible-playbook RESOLVE-base.yml -K --ask-vault-pass
```

`-K` is now the `admin` password. It connects with `~/.ssh/gradus-prod-admin-id_ed25519` (`admin_ssh_key`).

It refuses to run as anyone but `admin`. It installs the firewall, sshguard, unattended-upgrades, journald limits and Caddy, and keeps the umask policy and both users converged. It replaces `10-hardening.conf` with the full sshd configuration (modern ciphers and KEX, `AllowUsers admin deploy`), and once sshd has restarted it deletes `initial` with its home directory. If `initial` still has processes running, it says so and skips the removal; log out and re-run. It ends with the listener audit.

### Confirm

Note: The audit did its job and caught a real public listener the plan didn’t know about: `systemd-resolved` answering LLMNR (Link-Local Multicast Name Resolution) on port 5355, on every interface, over TCP and UDP. The Incus Debian 13 image uses systemd-resolved, and Ex2’s image may too.

The server only needs resolved’s loopback DNS stub, which the audit already allowed. So  LLMNR and multicast DNS are turned off in `RESOLVE-base.yml` rather than loosen the audit. This was done in version v0.3.2.

```bash
ssh -t -i ~/.ssh/gradus-prod-admin-id_ed25519 admin@10.119.134.236 'resolvectl status | grep -iE "llmnr|mdns"; sudo /usr/local/sbin/audit-listeners.sh'
```

Finally, on the laptop clean up the initial key:

```sh
rm ~/.ssh/gradus-raw-initial-id_ed25519 ~/.ssh/gradus-raw-initial-id_ed25519.pub
laptop$ ssh root@<ip>          # must be refused
laptop$ ssh initial@<ip>       # must be refused
```

If the panel injected `gradus-raw-initial-id_ed25519.pub` for root, clear it too: `sudo truncate -s 0 /root/.ssh/authorized_keys`.

## Appendix: the same steps by hand

### Umask policy

The goal is that new files are not world-readable by default, and new home directories are private. Debian 13 defaults to umask `022`. This sets `027` (owner full, group read, others nothing) and `0700` home directories. It has to happen before `admin` and `deploy` are created, because `useradd` reads these values when it makes their homes.

#### login.defs

`UMASK` here is the system default used by `pam_umask` and `useradd`; `HOME_MODE` sets the mode of new home directories.

```sh
initial$ sudo sed -i 's/^UMASK[[:space:]].*/UMASK\t\t027/' /etc/login.defs
initial$ grep -q '^HOME_MODE' /etc/login.defs \
  && sudo sed -i 's/^HOME_MODE[[:space:]].*/HOME_MODE\t0700/' /etc/login.defs \
  || echo 'HOME_MODE	0700' | sudo tee -a /etc/login.defs
initial$ grep -E '^(UMASK|HOME_MODE|USERGROUPS_ENAB)' /etc/login.defs
```

Leave `USERGROUPS_ENAB yes` as it is. Each user gets a private group, which is what makes a group-read bit safe.

#### pam_umask for login sessions

SSH and console logins pick up the umask through `pam_umask`. Check that it is in the session stack, and add it if not:

```sh
initial$ grep pam_umask /etc/pam.d/common-session \
  || echo 'session optional pam_umask.so' | sudo tee -a /etc/pam.d/common-session
```

#### adduser, in case it is ever used

```sh
initial$ sudo sed -i 's/^#\?DIR_MODE=.*/DIR_MODE=0700/' /etc/adduser.conf
```

#### Check it

Open a new SSH session as `initial` (the policy applies at login, not to the session you are in):

```sh
initial$ umask        # expect 0027
initial$ touch /tmp/umask-test && stat -c '%a %n' /tmp/umask-test && rm /tmp/umask-test   # expect 640
```

### Admin and deploy users

#### admin

A member of `sudo`, logs in with its own ed25519 key, password for sudo and console only.

```sh
initial$ sudo useradd --create-home --shell /bin/bash --groups sudo admin
initial$ sudo passwd admin
initial$ sudo install -d -m 0700 -o admin -g admin /home/admin/.ssh
initial$ printf '%s\n' 'ssh-ed25519 AAAA... admin@laptop' | sudo tee /home/admin/.ssh/authorized_keys >/dev/null
initial$ sudo chown admin:admin /home/admin/.ssh/authorized_keys
initial$ sudo chmod 0600 /home/admin/.ssh/authorized_keys
```

#### deploy

No sudo and no password. The shell is `/bin/sh` rather than `nologin` because sshd runs the forced rrsync command through the login shell. Its `.ssh` is owned by root, so even a stolen deploy key cannot rewrite its own restrictions.

```sh
initial$ sudo useradd --create-home --shell /bin/sh deploy
initial$ sudo passwd --lock deploy
initial$ sudo install -d -m 0755 -o root -g root /home/deploy/.ssh
initial$ printf '%s\n' 'restrict,command="/usr/bin/rrsync /srv/sites" ssh-ed25519 AAAA... deploy@ci' \
  | sudo tee /home/deploy/.ssh/authorized_keys >/dev/null
initial$ sudo chmod 0644 /home/deploy/.ssh/authorized_keys
initial$ sudo install -d -m 0755 -o deploy -g deploy /srv/sites
```

To limit the key to your IP or the CI runner's, put `from="203.0.113.5"` after `restrict,`. You can add this later in `ansible/group_vars/all.yml` as `deploy_from`.

`/srv/sites` is `0755` on purpose, so Caddy (running as `caddy`) can read it.

#### Check both

```sh
initial$ id admin           # groups include sudo
initial$ id deploy          # no sudo
initial$ sudo passwd -S deploy    # L (locked)
initial$ stat -c '%a %U:%G %n' /home/admin /home/deploy /home/deploy/.ssh /home/deploy/.ssh/authorized_keys /srv/sites
```

Expect `700` on both homes, `755 root:root` and `644 root:root` for the deploy `.ssh` and its key file, and `755 deploy:deploy` on `/srv/sites`.

### Restricting SSH and removing initial

After checking `admin` and `deploy` as above:

```sh
admin$ echo 'AllowUsers admin deploy' | sudo tee -a /etc/ssh/sshd_config.d/10-hardening.conf >/dev/null
admin$ sudo sshd -t && sudo systemctl restart ssh
admin$ pgrep -u initial || sudo userdel --remove initial
```

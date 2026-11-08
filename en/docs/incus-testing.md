# Testing on a local Incus instance

Before touching the Ex2 server, rehearse the whole procedure on flow against a local Incus instance that stands in for a freshly delivered VPS. The rehearsal uses the same runbook (`docs/initial-setup.md`), the same playbooks and the same keys. Only the inventory file differs. Mistakes cost nothing here: a lockout is fixed with `incus exec`, and a snapshot taken at creation puts the instance back to a fresh state in seconds.

The harness lives in `test/incus/`:

- `./test/incus/launch.sh` creates the stand-in VPS, writes `test/incus/inventory.ini`, and snapshots it as `fresh`
- `./test/incus/quick-initial.sh` does the manual root and `initial` steps through `incus exec`, for repeat runs
- `./test/incus/verify.sh` checks the finished server from outside, the way the internet sees it; it also works against the real VPS

Every command below runs on flow, from the repo root unless it says `cd ansible`.

## Container or VM

A system container is the default. It starts in seconds and is the right tool for iterating on the playbooks. It shares flow's kernel, which changes a few things:

- `systemd-timesyncd` and `apparmor.service` skip themselves in containers through their own systemd conditions, since the host owns the clock and the AppArmor policy. `RESOLVE-base.yml` detects a container and only enables those two units there, rather than starting them. The AppArmor audit check reads the host kernel, so it still passes on flow.
- nftables runs in the container's own network namespace, but the kernel modules are flow's. A container cannot load them itself (see the host preparation below).
- An unattended-upgrades reboot restarts only the container.
- There is no provider console. `incus exec ex2-test -- bash` stands in for it, and like Ex2's console it does not depend on SSH at all.

A VM (`launch.sh vm`) has its own kernel, so it behaves like the KVM guest Ex2 actually sells: timesyncd and AppArmor run for real, and `incus console ex2-test` gives a text console where you log in as `admin` with its password, exactly the recovery path you would use on Ex2. It takes a minute or two to boot. Do the final rehearsal on a VM.

## Prepare flow

### Incus

Incus 6.0 from the Mint repositories is enough. Check that the default profile has a network and a root disk, and that the community image server is configured:

```sh
incus version
incus profile show default        # expect an eth0 nic and a root disk
incus remote list                 # expect "images" (images.linuxcontainers.org)
incus image list images: debian/13 # expect container and virtual-machine images
```

VMs also need KVM: `ls -l /dev/kvm` should exist and your user should be able to use it (Windows 11 already runs as a VM on flow, so this is in place).

### nftables modules, for containers only

Where: on flow itself, not inside the test instance. A container shares flow's kernel and cannot load modules, so its `systemd-modules-load` is masked; running these steps there gives "Unit systemd-modules-load.service is masked".

Check where you are:

```bash
systemd-detect-virt
```

Output example, on flow:

```bash
none
```

Inside a container it prints `lxc`. Leave it with `exit` first.

```bash
ssh -i ~/.ssh/gradus-raw-initial-id_ed25519 initial@web.incus
```

```bash
systemd-detect-virt
```

```bash
lxc
```

Check whether the modules are already loaded, which they usually are because flow's own firewall uses them:

```bash
lsmod | grep -E '^nf_tables|^nft_ct'
```

Output example:

```bash
nft_ct                 28672  3
nf_tables             389120  839 nft_ct,nft_compat,nft_masq,nft_chain_nat,nft_limit
```

If both lines appear, nothing more is needed here. Otherwise, load them at every boot:

```bash
printf '%s\n' nf_tables nft_ct | sudo tee /etc/modules-load.d/ex2-test-nftables.conf
```

Output example:

```bash
nf_tables
nft_ct
```

Load them now, without a reboot:

```bash
sudo modprobe -a nf_tables nft_ct
```

No output means success. Confirm with the `lsmod` command above.

Without them, the `nftables ruleset` task fails with "Operation not supported".

### Tools on the laptop

Ansible runs from its own virtual environment at `~/.venvs/ansible/<version>/ansible`, set up as described in `docs/ansible-venv.md`. Activate it in the shell you run the playbooks from:

```sh
./tools/make-ansible-venv.sh                     # once, and again after changing the pin
. ~/.venvs/ansible/current/bin/activate
sudo apt install rsync curl nmap whois
pipx install ssh-audit                           # optional, for the crypto check
```

Both Robert de Bock roles require ansible-core 2.12 or later; the pinned release brings 2.21.

### Keys and settings

Create the three keypairs, put the two public keys in `ansible/group_vars/all.yml`, and the admin password hash in `ansible/group_vars/web/vault.yml`, exactly as `docs/initial-setup.md` describes under "Before you start". Using the same keys for the rehearsal and the real server means the test exercises exactly what you will use.

The playbook commands below include `--ask-vault-pass`. To stop typing the vault password, keep it in a file only you can read and point `ansible.cfg` at it, then drop the flag:

```sh
install -d -m 0700 ~/.config/ex2
( umask 077; printf '%s\n' 'your-vault-password' > ~/.config/ex2/vault-pass )
# ansible/ansible.cfg, under [defaults]:  vault_password_file = ~/.config/ex2/vault-pass
```

Install the roles once, from `ansible/`:

```sh
ansible-galaxy install -r RESOLVE-requirements.yml
```

## Create the stand-in VPS

From the repo root:

```sh
./test/incus/launch.sh          # container
./test/incus/launch.sh vm       # or a VM
```

It launches `images:debian/13` as `ex2-test` with the plan's 1 vCPU and 1 GiB (and a 25 GiB disk for a VM). Then it installs `openssh-server` and puts `~/.ssh/gradus-raw-initial-id_ed25519.pub` in root's `authorized_keys`, which is what Ex2's panel key injection would leave you with. It writes `test/incus/inventory.ini` with the instance's address. On the same line it puts flow's own bridge address on the sshguard whitelist, because `verify.sh` fails logins on purpose. It clears stale host keys for that address from `known_hosts`, and takes a snapshot called `fresh`. It finishes by printing the IPv4 and IPv6 addresses.

Change the name with `EX2_TEST_NAME=ex2-vm test/incus/launch.sh vm`, for example to keep a container and a VM side by side; set the same variable for `quick-initial.sh`.

## Rehearse

Run a single command in the instance, without SSH:

```bash
incus exec ex2-test -- <command-goes-here>
```

Example:

```bash
incus exec ex2-test -- cat /etc/machine-id
```

Follow `docs/initial-setup.md` from "As root: create the initial user", with three substitutions:

- Where the runbook says console, use `incus exec ex2-test -- bash` (or `incus console ex2-test` on a VM; detach with `Ctrl+a q`).
- The Ex2 panel steps are already done by `launch.sh`.
- Every playbook command gets `-i ../test/incus/inventory.ini`:

```sh
ssh -i ~/.ssh/gradus-raw-initial-id_ed25519 initial@<ipv4> true && echo ok    # must print ok before Ansible will work
cd ansible
ansible-playbook -i ../test/incus/inventory.ini bootstrap.yml -u initial -K --ask-vault-pass
ansible-playbook -i ../test/incus/inventory.ini RESOLVE-base.yml -K --ask-vault-pass
```

`-K` asks for the server `initial` user's password (for sudo), then `--ask-vault-pass` for the vault password. The inventory names the host `ex2-test`; if your output says `web1`, you left out `-i ../test/incus/inventory.ini` and are aiming at the real-server inventory.

Do the manual steps by hand at least once, since that is the part you will do live on Ex2. After that, `./test/incus/quick-initial.sh` performs them through `incus exec` (it asks for the `initial` password), so repeat runs go straight to `bootstrap.yml`.

## Verify

### Outside of container

```sh
./test/incus/verify.sh                       # IPv4 from the inventory
./test/incus/verify.sh <ipv4> <ipv6>         # add the IPv6 address printed by launch.sh
```

#### Example

Grap you incus containers ip 4 and/or 6 addresses for the incus container from the container host system.

```bash
incus exec ex2-test -- ip a
```

Output example:

```bash
...
7: eth0@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 10:66:6a:4e:6f:15 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.119.134.236/24 metric 1024 brd 10.119.134.255 scope global dynamic eth0
       valid_lft 3103sec preferred_lft 3103sec
    inet6 fd42:48:ed9e:b152:1266:6aff:fe4e:6f15/64 scope global mngtmpaddr noprefixroute 
       valid_lft forever preferred_lft forever
    inet6 fe80::1266:6aff:fe4e:6f15/64 scope link proto kernel_ll 
       valid_lft forever preferred_lft forever
```

##### Running verify.sh

```bash
# using ip4
/test/incus/verify.sh 10.119.134.236
# using ip6
./test/incus/verify.sh fd42:48:ed9e:b152:1266:6aff:fe4e:6f15
```

###### ipv4 output example

Runs fairly quickly

```bash
Checking 10.119.134.236
PASS  admin logs in with its key
FAIL  root is refused
FAIL  initial is refused (removed)
FAIL  admin key is refused for deploy
PASS  deploy key gets no shell
FAIL  server offers publickey only, no password
FAIL  deploy can rsync into the sites root
FAIL  deploy can list what it pushed
PASS  deploy cannot read outside the sites root
FAIL  Caddy answers on port 80 (got '000')
```

###### ipv6 output example:

Hands for long periods of time before refused messages

```bash
Checking fd42:48:ed9e:b152:1266:6aff:fe4e:6f15
PASS  admin logs in with its key
FAIL  root is refused
FAIL  initial is refused (removed)
FAIL  admin key is refused for deploy
PASS  deploy key gets no shell
PASS  server offers publickey only, no password
FAIL  deploy can rsync into the sites root
FAIL  deploy can list what it pushed
PASS  deploy cannot read outside the sites root
FAIL  Caddy answers on port 80 (got '000')
PASS  IPv4 open TCP ports: none (expected 22 80 443)
SKIP  ssh-audit (pipx install ssh-audit)

5 passed, 6 failed
On the server, also run: ssh -t -i /home/initial/.ssh/gradus-dev-admin-id_ed25519 admin@fd42:48:ed9e:b152:1266:6aff:fe4e:6f15 sudo /usr/local/sbin/audit-listeners.sh
```

It stops at once if `admin` cannot log in, because the "is refused" checks would then pass for the wrong reason. Otherwise it checks that:

- root, `initial`, and the admin key used as `deploy` are each refused by sshd itself, not just unreachable
- the server offers public-key authentication only
- the deploy key authenticates but gets no shell, can rsync into `/srv/sites`, and cannot reach outside it
- Caddy answers on port 80
- only TCP 22, 80 and 443 are open on IPv4 and IPv6 (with nmap)
- ssh-audit reports no failures

It leaves a small `.verify/` directory in `/srv/sites`. Every line should read PASS.

### On the server

At the end of the output above run the commands:

log in to the container as admin and run `audit-listeners.sh`

```bash
ssh -t -i /home/initial/.ssh/gradus-dev-admin-id_ed25519 admin@fd42:48:ed9e:b152:1266:6aff:fe4e:6f15
sudo /usr/local/sbin/audit-listeners.sh
```

Output example:

```bash
loopback    udp  127.0.0.54:53                              systemd-resolve
loopback    udp  127.0.0.53%lo:53                           systemd-resolve
dhcp-client udp  10.119.134.236%eth0:68                     systemd-network
dhcp-client udp  [fe80::1266:6aff:fe4e:6f15]%eth0:546       systemd-network
ok          tcp  0.0.0.0:22                                 sshd
ok          tcp  127.0.0.1:2019                             caddy
loopback    tcp  127.0.0.53%lo:53                           systemd-resolve
loopback    tcp  127.0.0.54:53                              systemd-resolve
ok          tcp  *:80                                       caddy
ok          tcp  [::]:22                                    sshd
```

Every line should be `ok`, `loopback` or `dhcp-client`; any `UNEXPECTED` line is a listener to remove.

### Idempotence

Run `RESOLVE-base.yml` a second time, with the same command. The recap should show `changed=0`. Anything that changes on every run is a bug in the playbook, and on the real server it would hide real drift.

ansible command goes here:

```bash
```

### Reboot

ip4 example:

```sh
incus restart ex2-test
./test/incus/verify.sh 10.119.134.236
```

Example output on a properly configured container:

```bash
Checking 10.119.134.236
PASS  admin logs in with its key
FAIL  root is refused
FAIL  initial is refused (removed)
FAIL  admin key is refused for deploy
PASS  deploy key gets no shell
PASS  server offers publickey only, no password
PASS  deploy can rsync into the sites root
PASS  deploy can list what it pushed
PASS  deploy cannot read outside the sites root
PASS  Caddy answers on port 80 (HTTP 200)
PASS  IPv4 open TCP ports: 22 80  (expected 22 80 443)
SKIP  ssh-audit (pipx install ssh-audit)

8 passed, 3 failed
On the server, also run: ssh -t -i /home/initial/.ssh/gradus-dev-admin-id_ed25519 admin@10.119.134.236 sudo /usr/local/sbin/audit-listeners.sh
```

as seen in the message at the end of the output you can then log into your container:

```bash
ssh -t -i /home/initial/.ssh/gradus-dev-admin-id_ed25519 admin@10.119.134.236
```

and run audit-listeners.sh again

```bash
sudo /usr/local/sbin/audit-listeners.sh
```

and confirm everything is as it should be after the reboot test:

```bash
[sudo] password for admin: 
loopback    udp  127.0.0.54:53                              systemd-resolve
loopback    udp  127.0.0.53%lo:53                           systemd-resolve
dhcp-client udp  10.119.134.236%eth0:68                     systemd-network
dhcp-client udp  [fe80::1266:6aff:fe4e:6f15]%eth0:546       systemd-network
loopback    tcp  127.0.0.53%lo:53                           systemd-resolve
ok          tcp  0.0.0.0:22                                 sshd
ok          tcp  127.0.0.1:2019                             caddy
loopback    tcp  127.0.0.54:53                              systemd-resolve
ok          tcp  [::]:22                                    sshd
ok          tcp  *:80                                       caddy
```

This confirms the firewall, sshguard and Caddy come back by themselves, as they must after an unattended-upgrades reboot. Then log out if you are done or run the lockout drill below (recommened)

### Lockout drill

THIS DOES NOT LOCK OUT THE ADMIN USER

Practise the recovery you hope never to need. As `admin`, break SSH on purpose:

As the containers admin user run:

```sh
echo 'AllowUsers nobody' | sudo tee /etc/ssh/sshd_config.d/11-break.conf && sudo systemctl restart ssh
```

Output:

```bash
AllowUsers nobody
```

New SSH logins now fail. Recover without SSH: on a VM, `incus console ex2-test`, log in as `admin` with its password, then `sudo rm /etc/ssh/sshd_config.d/05-break.conf && sudo systemctl restart ssh`. On a container, `incus exec ex2-test -- bash` does the same job, but it skips the password, so only the VM drill proves the `admin` password works at a console.

## Start over, keep, or clean up

```sh
incus snapshot restore ex2-test fresh            # back to a just-delivered VPS
incus snapshot create ex2-test after-base        # keep a known-good state to test later changes from
incus delete --force ex2-test                    # remove it
```

After a restore, the instance has its original host keys again, so `known_hosts` still matches.

## Troubleshooting

These are the failures met on the first real rehearsal, in the order they turned up.

### Refuse to run with placeholder keys

`bootstrap.yml` stops before touching the server while `group_vars/all.yml` still holds `REPLACE` placeholders, or while the admin and deploy keys are the same keypair. Put the two public keys in `all.yml` and the password hash in the vault, as in "Keys and settings". This command shows what Ansible will use, without connecting to anything:

```sh
cd ansible
ansible-inventory -i ../test/incus/inventory.ini --host ex2-test --ask-vault-pass \
  | grep -E '"(admin|deploy)_pubkey|admin_password_hash|ansible_host'
```

### Network is unreachable, 203.0.113.10

That is the placeholder address in `ansible/inventory.ini`, which is for the real server and never routes. Add `-i ../test/incus/inventory.ini` to aim at the test instance.

### Too many authentication failures

ssh offered every key in your agent before the right one, and sshd hung up. `ansible.cfg` sets `IdentitiesOnly=yes`, and each playbook names its own key (`initial_ssh_key` for `bootstrap.yml`, `admin_ssh_key` for `RESOLVE-base.yml`), so this only appears with an older copy of the repo or a plain `ssh` without `-o IdentitiesOnly=yes`. `ssh-add -l` shows how many keys the agent offers.

### Asked for a password, then Permission denied

The server rejected the key, so the user does not exist yet or its `authorized_keys` does not match your key. `launch.sh` only sets up root, so on a fresh instance `initial` exists only after the runbook step or `quick-initial.sh`:

```sh
incus exec ex2-test -- id initial
ssh -o IdentitiesOnly=yes -i ~/.ssh/gradus-raw-initial-id_ed25519 root@<ipv4> true && echo root-ok
ssh-keygen -lf ~/.ssh/gradus-raw-initial-id_ed25519.pub
incus exec ex2-test -- ssh-keygen -lf /home/initial/.ssh/authorized_keys
incus exec ex2-test -- journalctl -u ssh -n 20 --no-pager
```

If `root-ok` does not print either, the instance holds an older key, typically because the keypair was regenerated after `launch.sh` ran. Restore and push the current one:

```sh
incus snapshot restore ex2-test fresh
incus file push ~/.ssh/gradus-raw-initial-id_ed25519.pub ex2-test/root/.ssh/authorized_keys --mode 0600 --uid 0 --gid 0
```

### RESOLVE-base.yml cannot connect as admin

`admin` only exists once `bootstrap.yml` has succeeded. Run them in order.

### Attempting to decrypt but no vault secrets found

The vault file is in use and the command has no vault password. Add `--ask-vault-pass`, or set `vault_password_file`. "Decryption failed" instead means the password is wrong; `ansible-vault view group_vars/web/vault.yml` tests it on its own.

### Permission denied on /var/lib/apt/lists/lock

`robertdebock.bootstrap` assumes it connects as root, and its package task ignores the play's `become` unless `bootstrap_become` is true. `bootstrap.yml` sets it from version 0.3.1 on; with an older copy, add `bootstrap_become: true` under the play's `vars:`.

### INJECT_FACTS_AS_VARS deprecation warning

It comes from `robertdebock.bootstrap`, which still reads facts such as `ansible_distribution` as top-level variables. `ansible.cfg` sets `inject_facts_as_vars = True` explicitly, which keeps the role working and silences the warning. ansible-core 2.24 removes the option, so check for a newer role release before moving to Ansible 15.

### Audit fails on systemd-resolve, port 5355

The listener audit at the end of `RESOLVE-base.yml` found systemd-resolved answering LLMNR, a local-network name protocol, on all interfaces. The firewall already drops it, but the base promises no public listeners beyond sshd and Caddy, so from version 0.3.2 `RESOLVE-base.yml` turns LLMNR and multicast DNS off. Its loopback DNS stub on `127.0.0.53` and `127.0.0.54` stays, and the audit lists it as `loopback`.

Confirm on the server:

```bash
ssh -t -i ~/.ssh/gradus-dev-admin-id_ed25519 admin@10.119.134.236 'resolvectl status | grep -iE "llmnr|mdns"; sudo /usr/local/sbin/audit-listeners.sh'
```

Output example:

```bash
         Protocols: -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
         Protocols: +DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
[sudo] password for admin:
loopback    udp  127.0.0.54:53                              systemd-resolve
loopback    udp  127.0.0.53%lo:53                           systemd-resolve
dhcp-client udp  10.119.134.236%eth0:68                     systemd-network
dhcp-client udp  [fe80::1266:6aff:fe4e:6f15]%eth0:546       systemd-network
ok          tcp  127.0.0.1:2019                             caddy
ok          tcp  0.0.0.0:22                                 sshd
loopback    tcp  127.0.0.54:53                              systemd-resolve
loopback    tcp  127.0.0.53%lo:53                           systemd-resolve
ok          tcp  [::]:22                                    sshd
ok          tcp  *:80                                       caddy
```

`-LLMNR -mDNS` on every line, and no line reading `UNEXPECTED`. Caddy has only port 80 until a real site with a domain is added to the Caddyfile.

### Unit systemd-modules-load.service is masked

The nftables module steps were run inside the test instance. Run them on flow, as in "nftables modules, for containers only"; `systemd-detect-virt` tells the two apart.

## What a local rehearsal cannot show

- Ex2's actual image: whether it ships cloud-init and a `50-cloud-init.conf`, ifupdown or systemd-networkd, and which extra packages it includes. The playbook's package removal and listener audit catch most surprises, but check `ss -tulpn` and `dpkg -l` on the real server before running anything.
- Exposure to the internet: real scanners, sshguard blocks and log volume.
- TLS certificates: Caddy cannot get a Let's Encrypt certificate for a private address. The default Caddyfile serves plain HTTP on port 80, which is what `verify.sh` checks; to test HTTPS locally, use `tls internal` in a site block.
- Provider features: snapshots, a provider firewall, reverse DNS and IPv6 allocation, which are the open questions in the README.

To rehearse the cloud-init route instead of the manual one, fill in the placeholders in `cloud-init/user-data.yaml` and launch the cloud variant with it attached. Skip `launch.sh` for this, since cloud-init creates `admin` itself, then run only `RESOLVE-base.yml` with an inventory pointing at the new address:

```sh
incus launch images:debian/13/cloud ex2-ci -c limits.memory=1GiB \
  -c cloud-init.user-data="$(cat cloud-init/user-data.yaml)"
```

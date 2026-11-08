mermaid
flowchart TD
 A["Laptop: generate production keypairs<br/>gradus-prod-admin-id_ed25519 + gradus-prod-deploy-id_ed25519<br/>+ gradus-raw-initial-id_ed25519 (throwaway)"] --> B["Laptop: generate admin password hash<br/>mkpasswd -m yescrypt"]
 B --> C["Laptop: set pubkeys in group_vars/all.yml<br/>set hash in vault.yml"]
 C --> D["Ex2 panel: create VPS<br/>Debian 13, note IP"]
 D --> E["Ex2 console: log in as root"]
 E --> F["Console: create initial user<br/>adduser --disabled-password --gecos '' initial<br/>inject initial pubkey<br/>usermod -aG sudo initial"]
 F --> G["Exit console"]
 G --> H["Laptop: confirm SSH as initial<br/>ssh -i gradus-raw-initial-id_ed25519 initial@IP sudo -v"]
 H --> I["Laptop: activate Ansible venv<br/>cd ansible/"]
 I --> J["ansible-playbook bootstrap.yml<br/>-u initial -K --ask-vault-pass"]
 J --> K["Keep initial session open<br/>Laptop: confirm SSH as admin<br/>ssh -i gradus-prod-admin-id_ed25519 admin@IP sudo -v"]
 K --> L["ansible-playbook base.yml<br/>-K --ask-vault-pass<br/>(deletes initial, full hardening)"]
 L --> M["Laptop: verify.sh against prod IP"]
 M --> N{Pass?}
 N -->|Yes| O["Deploy sites"]
 N -->|No| P[Troubleshoot]
 P --> L
```

## Why the `initial` user

| Concern | `bootstrap.sh` shortcut | Full `initial` path |
|---|---|---|
| Umask policy | Skipped (applied later by base.yml) | Applied by bootstrap.yml before any permanent user exists |
| User creation | Script does it ad hoc | `robertdebock.users` role, idempotent |
| Audit trail | Root actions over console, invisible to Ansible | Everything after console is Ansible |
| Cleanup | `initial` never existed | `base.yml` deletes `initial` |
| Recovery | If script half-fails, manual fix | Re-run `bootstrap.yml` |

The `initial` user is a throwaway. It exists only so that Ansible's first connection is as a non-root, non-admin user that `base.yml` deletes at the end. You never SSH as root, and every configuration change is captured in a playbook run.

## Laptop preparation

### Generate production keypairs

Three keys: admin (permanent, human), deploy (permanent, CI), initial (throwaway, deleted after bootstrap).

```sh
ssh-keygen -t ed25519 -f ~/.ssh/gradus-prod-admin-id_ed25519 -C admin@laptop
ssh-keygen -t ed25519 -f ~/.ssh/gradus-prod-deploy-id_ed25519 -C deploy@ci -N ''
ssh-keygen -t ed25519 -f ~/.ssh/gradus-raw-initial-id_ed25519 -C initial@laptop
```

The initial key is throwaway — once `base.yml` deletes the user, you can delete the keypair.

### Ansible setup

#### Generate the admin password hash

Used for sudo and the provider console only, never for SSH. Store in your password manager.

```sh
mkpasswd -m yescrypt
```

Ensure venv is enabled:

```bash
. ~/.venvs/ansible/current/bin/activate
```

Add admin password hash to the vault:

```bash
ansible-vault edit group_vars/web/vault.yml
```

Paste in the password hash:

```yaml
admin_password_hash: '$y$j9T$k.rs2L0nJjhJAmRNu5CtE0$CUGlgkyoMbSFNdxWQorRG6VTxhqHVm2hTOIKQ7YBtEC'
```

> **Placeholder hash.** The hash above was generated from the password `example` with `mkpasswd -m yescrypt`. It is not used on any server and is safe to publish, so secret scans can ignore it. Paste your own hash into the vault, never into the docs.

### Update group_vars/all.yml

Grab your public key values:

```bash
cat ~/.ssh/gradus-prod-admin-id_ed25519.pub
```

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8SAPdqr+DK1NZ/iP/JDRVl2kBZ5UoUjvAtSBac4qSZ admin@laptop
```

```bash
cat ~/.ssh/gradus-prod-deploy-id_ed25519.pub
```

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0706vZ9wovUj2+HEPf0x9Cnqaga27BNdnoV/UCX9V9 deploy@ci
```

```bash
cat ~/.ssh/gradus-raw-initial-id_ed25519.pub
```

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... initial@laptop
```

Edit `group_vars/all.yml`:

```bash
nano group_vars/all.yml
```

Paste in the corresponding public keys and set the initial SSH key:

```yaml
admin_pubkey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8SAPdqr+DK1NZ/iP/JDRVl2kBZ5UoUjvAtSBac4qSZ admin@laptop"
deploy_pubkey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0706vZ9wovUj2+HEPf0x9Cnqaga27BNdnoV/UCX9V9 deploy@ci"
admin_ssh_key: ~/.ssh/gradus-prod-admin-id_ed25519
initial_ssh_key: ~/.ssh/gradus-raw-initial-id_ed25519
```

### Record the initial pubkey for the console step

You'll paste this into the Ex2 console when creating the `initial` user:

```bash
cat ~/.ssh/gradus-raw-initial-id_ed25519.pub
```

Copy the entire line.

## Console steps (Ex2, as root)

Log into the Ex2 real-time console. These are the exact commands. Replace `PASTE_INITIAL_PUBKEY_HERE` with the value you copied above.

```sh
adduser --disabled-password --gecos "" initial
mkdir -p /home/initial/.ssh
echo "PASTE_INITIAL_PUBKEY_HERE" > /home/initial/.ssh/authorized_keys
chmod 700 /home/initial/.ssh
chmod 600 /home/initial/.ssh/authorized_keys
chown -R initial:initial /home/initial
usermod -aG sudo initial
```

That's it. No password, no shell tweaks, no sshd config changes. `bootstrap.yml` handles the rest. Exit the console.

## Ansible runs (laptop)

From the `ansible/` directory, with the venv active:

```sh
ansible-galaxy install -r requirements.yml
```

First run — as `initial`, creates admin + deploy, applies umask policy:

```sh
ansible-playbook bootstrap.yml -u initial -K --ask-vault-pass
```

Confirm admin works BEFORE closing the initial session:

```sh
ssh -i ~/.ssh/gradus-prod-admin-id_ed25519 admin@IP sudo -v
```

Second run — as admin, full hardening, deletes `initial`:

```sh
ansible-playbook base.yml -K --ask-vault-pass
```

Keep the `initial` SSH session open in a terminal tab while running `base.yml`. If `base.yml` locks you out of SSH somehow, you still have that session and the console. Once `base.yml` passes, close the initial session — the user is gone.

## Verify from outside

```sh
test/incus/verify.sh <prod_ipv4> <prod_ipv6>
```

Or manually:

```sh
nmap -Pn -p- <ipv4> # expect 22, 80, 443 open
nmap -6 -Pn -p- <ipv6> # same over IPv6
nmap -Pn -sU -p 443 <ipv4> # QUIC
ssh-audit <ip> # crypto check
ssh root@<ip> # must be refused
```

## Naming convention

| Purpose | Test (Incus) | Production | Lifetime |
|---|---|---|---|
| Admin (human, sudo, console fallback) | `~/.ssh/gradus-dev-admin-id_ed25519` | `~/.ssh/gradus-prod-admin-id_ed25519` | Permanent |
| Deploy (CI/rsync, confined to rrsync) | `~/.ssh/gradus-dev-deploy-id_ed25519` | `~/.ssh/gradus-prod-deploy-id_ed25519` | Permanent |
| Initial (throwaway, bootstrap only) | `~/.ssh/gradus-raw-initial-id_ed25519` | `~/.ssh/gradus-raw-initial-id_ed25519` | Deleted after bootstrap.yml |

The `gradus-prod-` prefix makes it obvious which key is which in `ssh-agent`, prevents accidentally deploying to prod with a test key, and scales if you add a staging environment later.

## Firewall note

UFW is stable and maintained on Debian 13 (v0.36.2-9, nftables front-end). UC-Gradus uses raw nftables instead because:

- sshguard writes nftables sets directly; UFW's abstraction fights that integration
- The ruleset surgically replaces only its own table (`inet UCGradus`) so a reload doesn't wipe sshguard's dynamic blocks
- `audit-listeners.sh` checks for that specific table and its chains
- Robert de Bock's firewall role targets UFW/iptables/firewalld — evaluated and skipped

No change needed. Raw nftables is the correct choice for this stack.

## Alternative: bootstrap.sh shortcut

If you ever want the faster path (console → script → SSH as admin → base.yml), `bootstrap/bootstrap.sh` creates `admin` and `deploy`, injects keys, installs python3/sudo/rsync. It skips the `initial` user and the umask policy (which `base.yml` applies anyway). Use it when you're rebuilding from scratch and don't need the forensic trail. The full `initial` path is the default because every change after the console is captured in Ansible.
```
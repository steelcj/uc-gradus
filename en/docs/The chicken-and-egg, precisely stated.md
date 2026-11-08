You're right, and the `initial` user has a legitimate purpose I dismissed too quickly. Let me reframe.

## The chicken-and-egg, precisely stated

`useradd` reads `/etc/login.defs` `UMASK` to set the home directory mode at creation time. If `login.defs` says `UMASK 022` (Debian default), the home dir is `0755`. If you write `UMASK 027` to `login.defs` and THEN create users, they get `0750`. But if `robertdebock.users` creates users before the login.defs write lands, you get `0755` home dirs and you'd have to chmod them after the fact.

The `initial` user solves this differently: by the time you're creating permanent users, you're operating as a user whose entire environment was built AFTER the umask policy was written. The ordering guarantee is structural (you can't SSH as `initial` until bootstrap finishes) rather than relying on task ordering within a single playbook.

## Three-playbook architecture

```
bootstrap.yml (ONE-TIME, as OOB user)
─────────────────────────────────────
 • robertdebock.bootstrap → python3, sudo, basic packages
 • Write /etc/login.defs → UMASK 027
 • Write /etc/profile.d/umask.sh → umask 027 (runtime enforcement)
 • Create `initial` user (home dir gets 0750 from login.defs)
 • Inject initial's SSH key
 • Lock root SSH (PermitRootLogin no, AllowUsers initial)
 • Output: "connect as initial, run normalize.yml"

Cannot re-run: root SSH is locked, OOB user is gone from SSH.

normalize.yml (IDEMPOTENT, as `initial` via sudo)
──────────────────────────────────────────────────
 • robertdebock.users → creates admin, deploy (0750 home dirs ✓)
 • tasks/deploy_access.yml → deploy key, /srv/sites
 • tasks/umask.yml → pam_umask, sshd AcceptEnv (defense in depth)
 • robertdebock.epel (if needed — not on Debian, skip)
 • Can re-run safely: users are idempotent, files are idempotent

base.yml (IDEMPOTENT, as `admin` via sudo)
───────────────────────────────────────────
 • sshd hardening (AllowUsers admin deploy, ciphers, KEX)
 • nftables ruleset (inet UCGradus table)
 • Caddy install + systemd
 • sshguard
 • unattended-upgrades
 • journald persistence
 • resolved LLMNR/mDNS off
 • audit-listeners.sh (fails loudly if drift)
 • Delete `initial` (job done, no longer needed)
```

## Why this is better than two playbooks

| Concern | Two playbooks (bootstrap + base) | Three playbooks |
|---|---|---|
| Re-run safety | bootstrap breaks on second run | normalize + base are safe to re-run |
| Umask ordering | Task-order dependent, fragile | Structural: initial exists only after login.defs is written |
| Audit trail | Console actions invisible to Ansible | Only the OOB→initial transition is manual |
| Recovery from bad normalize | Re-run normalize.yml | Re-run normalize.yml |
| Recovery from bad base.yml | Re-run base.yml | Re-run base.yml |
| Drift detection | base.yml audit catches it | base.yml audit catches it |

## Robert de Bock's roles in this model

| Role | Used where | Why |
|---|---|---|
| `robertdebock.bootstrap` | bootstrap.yml | Python + sudo, distro-agnostic, handles the `raw` module dance |
| `robertdebock.users` | normalize.yml | Idempotent user management, tested across distros |
| `robertdebock.epel` | normalize.yml (conditional) | `when: ansible_facts.os_family == 'RedHat'` — no-op on Debian |
| `robertdebock.umask` | normalize.yml (supplement) | Writes `~/.bashrc` for interactive sessions. Insufficient alone but harmless as belt-and-suspenders |
| `robertdebock.firewall` | NOT used | Targets iptables/ufw/firewalld. Your nftables template needs surgical table control that sshguard integrates with |
| `robertdebock.openssh` | NOT used | No cipher/KEX/AcceptEnv knobs exposed |
| `robertdebock.ntp` | NOT used | Uses chrony/ntpd; you use systemd-timesyncd |
| `robertdebock.auto_update` | NOT used | You use unattended-upgrades with backports origins |

The umask role is interesting as a supplement. On Debian 13, `~/.bashrc` is sourced by interactive bash only. Your deploys go through `sshd` → forced command → `/bin/sh -c rrsync`, which never reads bashrc. So the role alone wouldn't fix the 640-files-served-as-403 problem. But your `rsync --chmod=D755,F644` flag in the deploy command already handles that at the transport level. The umask role adds interactive-session correctness for admin's own file creation (creating a new site directory by hand, for example). Cheap insurance, zero risk.

## bootstrap.yml sketch

```yaml
---
# One-time bootstrap. Connect as whatever user the image provides.
# Creates the `initial` user and locks OOB access.
#
# Usage:
# ansible-playbook bootstrap.yml -e "ansible_host=203.0.113.10" \
# -u root --ask-vault-pass
#
# After this run, connect as initial and run normalize.yml.

- name: Bootstrap a fresh host
 hosts: all
 become: true
 gather_facts: false
 vars:
 # These come from -e flags or a minimal inventory
 # ansible_host: IP
 # ansible_user: root (or ubuntu, or debian — whatever the image gives)
 # initial_pubkey: the throwaway key for this run
 # admin_pubkey: the permanent admin key (stored for normalize to use later)

 pre_tasks:
 - name: Assert inputs
 ansible.builtin.assert:
 that:
 - ansible_host is defined
 - ansible_user is defined
 - initial_pubkey is defined
 - admin_pubkey is defined
 - deploy_pubkey is defined
 - admin_password_hash is defined
 fail_msg: "Pass ansible_host, ansible_user, initial_pubkey, admin_pubkey, deploy_pubkey, admin_password_hash"
 delegate_to: localhost
 become: false
 run_once: true

 tasks:
 - name: Prepare the host for Ansible
 ansible.builtin.include_role:
 name: robertdebock.bootstrap
 vars:
 bootstrap_become: true

 - name: Gather facts
 ansible.builtin.setup:

 - name: Require Debian 13
 ansible.builtin.assert:
 that:
 - ansible_facts.distribution == "Debian"
 - ansible_facts.distribution_major_version == "13"
 fail_msg: "This base targets Debian 13 (trixie) only."

 - name: Umask default — before any user exists
 ansible.builtin.lineinfile:
 path: /etc/login.defs
 regexp: '^UMASK\s'
 line: 'UMASK 027'
 backup: true

 - name: Runtime umask enforcement
 ansible.builtin.copy:
 dest: /etc/profile.d/umask.sh
 content: |
 # UC-Gradus: enforce 027 for all login shells
 umask 027
 owner: root
 group: root
 mode: "0644"

 - name: Create initial user (gets 0750 home dir from login.defs)
 ansible.builtin.user:
 name: initial
 shell: /bin/bash
 groups: [sudo]
 create_home: true
 home_mode: "0750"
 password_lock: true

 - name: Inject initial SSH key
 ansible.posix.authorized_key:
 user: initial
 key: "{{ initial_pubkey }}"
 state: present

 - name: Lock SSH to initial only (temporary)
 ansible.builtin.copy:
 dest: /etc/ssh/sshd_config.d/10-bootstrap.conf
 content: |
 PermitRootLogin no
 PasswordAuthentication no
 KbdInteractiveAuthentication no
 AuthenticationMethods publickey
 AllowUsers initial
 owner: root
 group: root
 mode: "0644"
 notify: Restart sshd

 handlers:
 - name: Restart sshd
 ansible.builtin.systemd:
 name: ssh
 state: restarted

 post_run:
 - name: Next step
 ansible.builtin.debug:
 msg:
 - "Bootstrap complete. Root SSH is locked."
 - "Connect as initial:"
 - " ssh -i ~/.ssh/gradus-raw-initial-id_ed25519 initial@{{ ansible_host }}"
 - "Then run: ansible-playbook normalize.yml -u initial -K"
```

## normalize.yml sketch

```yaml
---
# Idempotent normalization. Run as `initial`, sudo to root.
# Creates permanent users, deploy access, and the full umask policy.
# Safe to re-run — corrects drift.
#
# Usage:
# ansible-playbook normalize.yml -i inventory/prod.ini -u initial -K --ask-vault-pass

- name: Normalize the host
 hosts: web
 become: true
 gather_facts: true

 pre_tasks:
 - name: Assert we are not connected as root or admin
 ansible.builtin.assert:
 that:
 - ansible_user_id == 'initial'
 fail_msg: "normalize.yml must run as the initial user. Use -u initial."
 delegate_to: localhost
 become: false
 run_once: true

 roles:
 - role: robertdebock.users
 vars:
 # users list defined in group_vars/all.yml
 # admin + deploy, both with correct home_mode 0750

 tasks:
 - name: Deploy key and sites root
 ansible.builtin.include_tasks: tasks/deploy_access.yml

 - name: Umask policy (full system-wide)
 ansible.builtin.include_tasks: tasks/umask.yml

 - name: Umask for interactive sessions (belt and suspenders)
 ansible.builtin.include_role:
 name: robertdebock.umask
 vars:
 umask: "0027"
 umask_users:
 - admin
 - deploy

 - name: Next step
 ansible.builtin.debug:
 msg:
 - "Normalized. Test admin login:"
 - " ssh -i {{ admin_ssh_key }} admin@{{ ansible_host }} sudo -v"
 - "Then run: ansible-playbook base.yml -K --ask-vault-pass"
```

## base.yml — unchanged in structure

Same as it exists today, plus one addition at the end:

```yaml
 - name: Remove the initial user
 ansible.builtin.user:
 name: initial
 state: absent
 remove: true
 when: "'initial' in ansible_facts.getent_passwd"
```

Guarded by the `when` so re-runs don't fail on an already-deleted user.

## What changes in the existing repo

| File | Change |
|---|---|
| `bootstrap.yml` | Rewrite as above. One-time, as OOB user, creates `initial`, locks root SSH |
| `normalize.yml` | New. Idempotent, as `initial`, creates permanent users + umask + deploy |
| `base.yml` | Add the `initial` cleanup task. Everything else stays |
| `tasks/umask.yml` | Stays. System-wide enforcement (login.defs already done by bootstrap; this handles profile.d, pam, sshd AcceptEnv) |
| `requirements.yml` | Add `robertdebock.umask` (optional supplement) |
| `group_vars/all.yml` | Add `initial_pubkey`. Keep everything else |
| `gradus` helper | Three commands: `normalize`, `base`, `verify` (bootstrap is one-time and manual) |

## The gradus helper revised

```sh
#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:?Usage: gradus <bootstrap|normalize|base|verify> [args...]}"
shift

ANSIBLE="$(cd "$(dirname "$0")/../ansible" && pwd)"

case "$ACTION" in
 bootstrap)
 # gradus bootstrap <ip> <oob_user> <initial_key_path>
 IP="${1:?Need IP}"
 OOB_USER="${2:?Need OOB user}"
 INITIAL_KEY="${3:?Need initial private key}"
 ansible-playbook "$ANSIBLE/bootstrap.yml" \
 -e "ansible_host=$IP ansible_user=$OOB_USER" \
 -u "$OOB_USER" -K --ask-vault-pass "$@"
;;
 normalize)
 # gradus normalize <ip>
 IP="${1:?Need IP}"
 ansible-playbook "$ANSIBLE/normalize.yml" \
 -e "ansible_host=$IP" \
 -u initial -K --ask-vault-pass "$@"
;;
 base)
 # gradus base <ip>
 IP="${1:?Need IP}"
 ansible-playbook "$ANSIBLE/base.yml" \
 -e "ansible_host=$IP" \
 -K --ask-vault-pass "$@"
;;
 check)
 IP="${1:?Need IP}"
 ansible-playbook "$ANSIBLE/base.yml" \
 -e "ansible_host=$IP" \
 -K --check --diff --ask-vault-pass "$@"
;;
 verify)
 IP="${1:?Need IP}"
 "$(dirname "$0")/../test/incus/verify.sh" "$IP" "${2:-}"
;;
 *)
 echo "Commands: bootstrap, normalize, base, check, verify"
 exit 1
;;
esac
```

Full cycle for a new host:

```sh
# 1. One-time bootstrap (as root, locks root SSH)
gradus bootstrap 203.0.113.10 root ~/.ssh/gradus-raw-initial-id_ed25519

# 2. Normalize (as initial, creates admin + deploy)
gradus normalize 203.0.113.10

# 3. Harden (as admin, deletes initial)
gradus base 203.0.113.10

# 4. Verify from outside
gradus verify 203.0.113.10

# 5. Later, check for drift
gradus check 203.0.113.10
```

Want me to write the full v0.6.0 flowchart document incorporating this three-playbook model?
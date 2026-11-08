# Changelog

## 0.3.3 (2026-11-06)

### Fixed

- `verify.sh` reported FAIL for root, `initial` and the admin key on `deploy`, and failed the rsync checks, on a correct server whenever the ssh agent held several keys: sshd's `MaxAuthTries 3` disconnected with "Too many authentication failures" before the check. It now sets `IdentitiesOnly=yes`.
- `verify.sh` accepts an IPv6 address as its first argument: it brackets the address for curl and rsync, and scans and labels the port scan by address family. Its Caddy check also ignores any HTTP proxy settings.
- `launch.sh` whitelists flow's IPv6 bridge address for sshguard as well as the IPv4 one, so IPv6 verification runs do not get flow blocked.
- The lockout drill in `en/docs/incus-testing.md` used `AllowUsers nobody`, which does not lock `admin` out: `AllowUsers` lines add up across files. It now uses `DenyUsers admin`, which sshd checks first, and walks through the refused login, recovery and confirmation.

### Changed

- New `en/docs/process-flowchart.md`: Mermaid flowcharts (top-down) of the overview, preparing flow, the first session, verify and recovery, and deploying.
- `en/docs/incus-testing.md` example outputs show what a correct server gives, the idempotence step has its command and expected recap, and Troubleshooting covers false failures and sshguard blocks from `verify.sh`.

## 0.3.2 (2026-11-04)

### Fixed

- The listener audit at the end of `base.yml` failed on images that use systemd-resolved, including Incus's Debian 13, because resolved answers LLMNR on port 5355 on every interface. `base.yml` now writes `/etc/systemd/resolved.conf.d/no-multicast.conf` with `LLMNR=no` and `MulticastDNS=no` and restarts resolved, when resolved is installed. Its loopback DNS stub stays.

## 0.3.1 (2026-11-04)

Fixes from the first rehearsal on a local Incus container.

### Fixed

- `bootstrap.yml` failed at the `robertdebock.bootstrap` package task with "Could not open lock file /var/lib/apt/lists/lock - open (13: Permission denied)". The role assumes it connects as root and ignores the play's `become` unless `bootstrap_become` is true; the play now sets it.
- SSH runs could end with "Too many authentication failures" when the agent held several keys. `ansible.cfg` now adds `IdentitiesOnly=yes` to Ansible's default ssh options, and each playbook names its key: `bootstrap.yml` uses `initial_ssh_key`, `base.yml` uses `admin_ssh_key`.
- The admin check in `base.yml` read the `ansible_env` and `ansible_user_id` top-level fact variables, which ansible-core 2.24 removes. It now reads `ansible_facts`.

### Changed

- `ansible.cfg` sets `inject_facts_as_vars = True` explicitly. `robertdebock.bootstrap` 7.1.7 still needs it, and setting it silences the INJECT_FACTS_AS_VARS deprecation warning until ansible-core 2.24.
- The admin password hash lives only in `ansible/group_vars/web/vault.yml`, encrypted with ansible-vault; `group_vars/all.yml` keeps a placeholder, and all playbook commands in the en/docs pass `--ask-vault-pass`.
- `ansible/inventory.ini` is back to the documentation address `203.0.113.10` with a comment; local tests use `test/incus/inventory.ini`, written by `launch.sh`.
- `en/docs/incus-testing.md` gained a troubleshooting section covering every failure from the first rehearsal, replacing pasted session output.
- `en/docs/ansible-venv.md` explains how to list available Ansible releases and which ansible-core each brings, and commands across the en/docs drop the `laptop$` prompt where every command runs on the laptop.

## 0.3.0 (2026-11-04)

- Initial user runbook, `bootstrap.yml` with the `robertdebock.bootstrap` and `robertdebock.users` roles, local Incus test harness, and Ansible in a versioned virtual environment.

---
name: session-report-2026-11-07-2113
org: universal-cake
lang: en
type: session-report
date: 2026-11-07
---

# Session report: 2026-11-07

- Repository: `uc-gradus`, branch `main`, no commits yet, remote `https://github.com/steelcj/uc-gradus`
- Work done: a secrets audit before publishing, fixes for the security findings, SSH key renames, and an audit against the README (findings only, nothing applied)
- Nothing was committed or pushed.

## 1. Secrets audit

Full report: [`en/docs/audits/2026-11-07-pre-publication-secrets-audit.md`](../audits/2026-11-07-pre-publication-secrets-audit.md)

No secret scanner (gitleaks, trufflehog, detect-secrets) was installed, so every file git would track was searched by hand for:

- private keys and API tokens
- password hashes
- IP addresses, email addresses and domains
- home paths and key file names

Each hit was then checked in context.

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | High | Two real-looking yescrypt admin password hashes in plain text in the docs | Fixed |
| 2 | Low | Stray file `ansible/deploy@10.119.134.236` (contents: `flow`) | Fixed (deleted) |
| 3 | Info | Personal details: domains, a personal key file name, chat transcripts, live public keys | Key name fixed; the rest is the owner's call |
| 4 | Info | `ansible/inventory.ini` points `web1` at the Incus test container | Open |

Reviewed and acceptable:

- `ansible/group_vars/web/vault.yml` is encrypted with Ansible Vault (AES256).
- The upstream test private keys under `ansible/roles/` are gitignored; `git check-ignore` confirmed it.
- No API tokens were found.
- All IP addresses are private, loopback or documentation-only ranges.

## 2. Security fixes applied

### Password hashes replaced with a placeholder

All four copies of the two real hashes were replaced with a placeholder generated from the password `example` (`mkpasswd -m yescrypt`). Hashing `example` again with the same salt gives the same value.

```text
$y$j9T$k.rs2L0nJjhJAmRNu5CtE0$CUGlgkyoMbSFNdxWQorRG6VTxhqHVm2hTOIKQ7YBtEC
```

| File | Change |
|------|--------|
| `en/docs/initial-setup.md` | "Example output" block and the vault line: placeholder plus a "Placeholder hash" note after each |
| `en/docs/process-flowchart-v0.4.0-production.md` | Vault line: placeholder plus note. Also added the missing space after `admin_password_hash:`; without it, YAML doesn't read the line as a key |
| `en/docs/process-flowchart-v0.4.1-production.md` | Vault line: placeholder plus note |

A search confirms no copies of the old hashes and no other full hashes remain.

### Stray file deleted

`ansible/deploy@10.119.134.236` was removed after checking its contents.

### SSH key names standardised

Every key name now follows the README scheme `gradus-<env>-<purpose>-<algorithm>`, plus the `raw` initial keypair:

| Old name | New name |
|----------|----------|
| `ex2_initial`, `gradus_prod_initial`, `gradus_dev_initial`, `chris_steel_personal_id_ed25519` | `gradus-raw-initial-id_ed25519` |
| `ex2_admin` / `ex2_deploy` in Incus test files | `gradus-dev-{admin,deploy}-id_ed25519` |
| `ex2_admin` / `ex2_deploy` in real-server files | `gradus-prod-{admin,deploy}-id_ed25519` |
| `gradus_dev_*`, `gradus_prod_*` | `gradus-{dev,prod}-{admin,deploy}-id_ed25519` |

Environment chosen for each file:

- **dev:** `test/incus/launch.sh`, `quick-initial.sh` and `verify.sh`; `en/docs/incus-testing.md`; and the three design docs.
- **prod:** `ansible/group_vars/all.yml`, `ansible/bootstrap.yml`, `en/docs/initial-setup.md`, `OLD-README.md`, the chicken-and-egg doc, and all the process flowcharts. In the production flowcharts' naming tables, the "Test (Incus)" column uses the dev names.

Only names were changed. A search confirms no old names remain.

### Audit report updated

Findings 1, 2 and the personal key name in finding 3 are marked fixed, with resolution notes. The placeholder hash is listed as a known false positive.

## 3. Audit against the README (findings only)

Task file: [`task-normalize-uc-gradus-repository-to-match-readme.md`](../../../task-normalize-uc-gradus-repository-to-match-readme.md). Authority: `README.md` v0.3.0.

Following the task's rules, findings were presented first and **nothing has been applied**.

### Already matching

- Debian 13 only: both playbooks check for it.
- SSH key names: fixed in section 2.
- Scope: nothing references containers-as-a-product, orchestration or Kubernetes.

### Proposed changes

| # | File(s) | Current | Required (README) | Proposed action |
|---|---|---|---|---|
| 1 | `ansible/ansible.cfg`, `ansible/group_vars/all.yml`, `ansible/*.yml` | Everything under `ansible/` | `ansible.cfg`, `group_vars/`, `playbooks/`, `roles/` at the repo root | Move them, then fix relative paths (`roles_path`, `inventory`, `tasks/`, `templates/`, `files/`) |
| 2 | `ansible/inventory.ini` | One file, group `[web]` | `inventory/{dev,stage,prod}/hosts.ini`, group `[targets]`, plus `inventory/dev/group_vars/targets.yml` | Split by environment. Rename `[web]` to `[targets]` everywhere, including `hosts: web` and `launch.sh` |
| 3 | `ansible/group_vars/web/vault.yml` | Under group `web` | Group `targets`, environment-specific | Move it. It stays encrypted and its content is unchanged |
| 4 | `ansible/bootstrap.yml` | Layer 1, named bootstrap | `playbooks/onboarding.yml` | Rename and update references |
| 5 | `ansible/base.yml` | Layer 2, and it also installs and enables Caddy | `playbooks/normalize.yml` without Caddy | Rename. Move the Caddy tasks out |
| 6 | (missing) | Doesn't exist | `playbooks/caddy-server.yml` | Create it with the Caddy tasks from `base.yml` only |
| 7 | (missing) | Doesn't exist | `scripts/gradus` (`onboard`, `normalize`, `roles list`, `roles apply N`, `--env`) | Create a minimal stub with a TODO (task rule 4) |
| 8 | `ansible/group_vars/all.yml` | `admin_pubkey`/`deploy_pubkey` hold key text; `admin_user: admin` | `ssh_admin_key`/`ssh_deploy_key` hold `.pub` paths per environment | Rename the variables, or change the README (decision C) |
| 9 | `ansible/requirements.yml` | 2 roles (bootstrap, users) | 11 robertdebock roles | Decision A |
| 10 | `bootstrap/bootstrap.sh`, `cloud-init/user-data.yaml` | Other ways to do layer 1 | Not in the README's structure | Mark `# OUT OF SCOPE — not in README v0.3.0`. Do not delete |
| 11 | `tools/make-ansible-venv.sh`, `test/incus/*` | Present | Not in the README's structure; Incus testing is in scope | Mark `tools/` out of scope. Keep `test/incus/` (decision D) |
| 12 | Current docs: `initial-setup.md`, `incus-testing.md`, `process-flowchart.md`, `ansible-venv.md` | `bootstrap.yml`/`base.yml`, `ansible-playbook …`, `[web]`, "Ex2" | `gradus onboard`/`normalize`, new paths | Update once 1–7 are settled |
| 13 | Dated and versioned docs: `design/*`, `*-v0.x.x*.md`, chat transcripts, `The chicken-and-egg…`, `CHANGELOG.md`, `OLD-README.md` | Old commands (`gradus bootstrap/base/verify/check`) and playbooks | Same as above | Decision B |

### Decisions waiting on the owner

**A. README roles vs working code.** The README lists `epel, update, auto_update, cron, ntp, openssh, fail2ban, firewall, umask`. `base.yml` already does those jobs with its own tasks:

| README role | Current code |
|---|---|
| `firewall` | nftables template |
| `fail2ban` | sshguard |
| `openssh` | sshd drop-in |
| `ntp` | timesyncd |
| `auto_update` | unattended-upgrades |
| `umask` | `tasks/umask.yml` |

The options are to swap in the roles (follows the README, breaks task rule 5, "Preserve existing working code") or to change the README's list (recommended). `epel` is a RHEL repository and does nothing on Debian.

A. README roles vs working code.

​	* Response: prepend working code files with README.md discrepancy with RESOLVE-<code-file-name>

**B. Historical docs.** Rewrite them, or freeze them and place them in a subdirectory called artefacts with a one-line note "Historical. Superseded by README v0.3.0." (recommended).

**C. Contradictions inside the README.** Task rule 3 can't settle these, because the README is the authority:

- It says each environment gets two keypairs, and the naming table allows only `dev|stage|prod` × `admin|deploy`. Yet the keypair inventory lists `gradus-raw-initial-id_ed25519`.
- Commands has no `--env` flag; Testing uses `--env dev`.
- Testing restores a snapshot called `pre-onboard`, which nothing creates. `launch.sh` creates one called `fresh`.
- Quick Start says onboarding removes the out-of-box user. Today normalize (`base.yml`) does that, and it has to, because onboarding runs as that user.
- Normalize is described as setting up "monitoring" and "cron". Neither exists, and building them would expand the scope.
- The structure tree shows `decisions` nested inside `design`. On disk they sit side by side.

**D. Repo files the README's structure leaves out:** `test/incus/`, `CHANGELOG.md`, the task file, and now `en/docs/audits/` and `en/docs/sessions/`. Should they go into the README's structure, or be marked out of scope?

## 4. Open items

Security:

- [ ] If either original password hash was for a password in use, or was pasted anywhere else, change the admin password and update the vault.
- [ ] Make sure the vault password is long and random. In a public repository anyone can try to guess it offline.
- [ ] Decide whether the personal domains, chat transcripts and live public keys (finding 3) should be public.
- [ ] Point `ansible/inventory.ini` at the real server before the first production run (finding 4).
- [ ] Rename the key files on the laptop to the new names, or the scripts and playbooks won't find them.
- [ ] Optional: install gitleaks as a pre-commit hook, and tell it to skip the placeholder hash in `.gitleaks.toml`.

README audit:

- [ ] Decide A–D above. Then the final change table will be shown and applied on confirmation.

## Observations left out of scope

These came up during the session and were deliberately left alone, because the work was limited to security fixes:

- `initial_ssh_key` is used by `bootstrap.yml`, but its only definition, in `ansible/group_vars/all.yml`, is commented out.
- `ansible/group_vars/all.yml:18` has a commented-out `admin_ssh_key` line that now matches the live line below it.

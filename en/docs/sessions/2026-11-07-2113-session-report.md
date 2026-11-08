---
name: session-report-2026-11-07-2113
org: universal-cake
lang: en
type: session-report
date: 2026-11-07
---

# Session report: 2026-11-07

- Repository: `uc-gradus`, branch `main`, no commits yet, remote `https://github.com/steelcj/uc-gradus`
- Work done: a secrets audit before publishing, fixes for the security findings, SSH key renames, an audit against the README, and decisions A (`RESOLVE-` renames), B (historical docs moved to `artifacts/`) and D (README structure extended) from that audit applied, the task prompt filed under `en/docs/sessions/`, the session method written down in `CLAUDE.md` and as a uc-processes process, and the release ceremony documented in uc-processes
- Committed on each repository's `main` and pushed at the owner's request (section 9).

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

The two flowcharts have since moved to `en/docs/artifacts/` (decision B).

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

The design docs, process flowcharts, chicken-and-egg doc and `OLD-README.md` named above have since moved into `artifacts/` folders (decision B).

### Audit report updated

Findings 1, 2 and the personal key name in finding 3 are marked fixed, with resolution notes. The placeholder hash is listed as a known false positive.

## 3. Audit against the README (findings only)

Task file: [`2026-11-07-2109-session-prompt.md`](2026-11-07-2109-session-prompt.md). It was originally `task-normalize-uc-gradus-repository-to-match-readme.md` at the repo root, and the timestamp is when work on it began. Authority: `README.md` v0.3.0.

Following the task's rules, findings were presented first. Decisions A, B and D have been applied (see [Decision A applied](#decision-a-applied), [Decision B applied](#decision-b-applied) and [Decision D applied](#decision-d-applied)); proposed changes 1–12 are still waiting.

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
| 9 | `ansible/requirements.yml` (now `ansible/RESOLVE-requirements.yml`) | 2 roles (bootstrap, users) | 11 robertdebock roles | Marked by decision A; the role mismatch itself is still open |
| 10 | `bootstrap/bootstrap.sh`, `cloud-init/user-data.yaml` | Other ways to do layer 1 | Not in the README's structure | Mark `# OUT OF SCOPE — not in README v0.3.0`. Do not delete |
| 11 | `tools/make-ansible-venv.sh`, `test/incus/*` | Present | Not in the README's structure; Incus testing is in scope | Mark `tools/` out of scope. `test/incus/` is now in the README's structure (decision D) |
| 12 | Current docs: `initial-setup.md`, `incus-testing.md`, `process-flowchart.md`, `ansible-venv.md` | `bootstrap.yml`/`base.yml`, `ansible-playbook …`, `[web]`, "Ex2" | `gradus onboard`/`normalize`, new paths | Update once 1–7 are settled |
| 13 | Dated and versioned docs: `design/*`, `*-v0.x.x*.md`, chat transcripts, `The chicken-and-egg…`, `CHANGELOG.md`, `OLD-README.md` | Old commands (`gradus bootstrap/base/verify/check`) and playbooks | Same as above | Done by decision B: frozen in `artifacts/` folders (`CHANGELOG.md` excluded) |

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

The options were to swap in the roles (follows the README, breaks task rule 5, "Preserve existing working code") or to change the README's list. `epel` is a RHEL repository and does nothing on Debian.

**Owner's response:** "prepend working code files with README.md discrepancy with RESOLVE-<code-file-name>". Applied as described below. The underlying choice, roles or the README list, is still to be made for each `RESOLVE-` file.

**B. Historical docs.** Rewrite them, or freeze them with a one-line note "Historical. Superseded by README v0.3.0." (recommended).

**Owner's response:** freeze them and move them into a subdirectory called `artifacts`, with the one-line note. The `artifacts` folder goes next to each file: `en/docs/<file>` becomes `en/docs/artifacts/<file>`, and `en/docs/design/<file>` becomes `en/docs/design/artifacts/<file>`. Applied as described below.

**C. Contradictions inside the README.** Task rule 3 can't settle these, because the README is the authority:

- It says each environment gets two keypairs, and the naming table allows only `dev|stage|prod` × `admin|deploy`. Yet the keypair inventory lists `gradus-raw-initial-id_ed25519`.
- Commands has no `--env` flag; Testing uses `--env dev`.
- Testing restores a snapshot called `pre-onboard`, which nothing creates. `launch.sh` creates one called `fresh`.
- Quick Start says onboarding removes the out-of-box user. Today normalize (`base.yml`) does that, and it has to, because onboarding runs as that user.
- Normalize is described as setting up "monitoring" and "cron". Neither exists, and building them would expand the scope.
- ~~The structure tree shows `design` nested inside `decisions`. On disk they sit side by side.~~ Resolved by decision D: the tree now shows them side by side.

**D. Repo files the README's structure leaves out:** `test/incus/`, `CHANGELOG.md`, the task file, and now `en/docs/audits/`, `en/docs/sessions/` and the `artifacts/` folders from decision B (repo root, `en/docs/`, `en/docs/design/`). Should they go into the README's structure, or be marked out of scope?

**Owner's response:** they go into the README's structure. Applied as described below.

### Decision A applied

Each working code file that conflicts with the README's role list was renamed to `RESOLVE-<code-file-name>`, after the change table was shown and confirmed:

| Old | New | README role(s) it conflicts with |
|---|---|---|
| `ansible/requirements.yml` | `ansible/RESOLVE-requirements.yml` | Lists 2 roles instead of the README's 11 |
| `ansible/base.yml` | `ansible/RESOLVE-base.yml` | `firewall`, `fail2ban`, `openssh`, `ntp`, `update`, `auto_update` |
| `ansible/tasks/umask.yml` | `ansible/tasks/RESOLVE-umask.yml` | `umask` |
| `ansible/templates/nftables.conf.j2` | `ansible/templates/RESOLVE-nftables.conf.j2` | `firewall` |
| `ansible/templates/sshd-hardening.conf.j2` | `ansible/templates/RESOLVE-sshd-hardening.conf.j2` | `openssh` |
| `ansible/templates/52unattended-upgrades-local.j2` | `ansible/templates/RESOLVE-52unattended-upgrades-local.j2` | `auto_update` |
| `ansible/files/20auto-upgrades` | `ansible/files/RESOLVE-20auto-upgrades` | `auto_update` |

`epel` and `cron` have no matching file, so nothing was renamed for them.

What else changed:

- **Code:** the `include_tasks` and `src:` lines in `RESOLVE-base.yml` and `bootstrap.yml`. Every reference resolves to an existing file.
- **Server unchanged:** the `dest:` paths stayed as they were, so the files land in the same places on the server.
- **Comments:** in `bootstrap.yml`, `group_vars/all.yml`, `RESOLVE-requirements.yml`, `bootstrap/bootstrap.sh`, `cloud-init/user-data.yaml` and `test/incus/verify.sh`.
- **Current docs:** `initial-setup.md`, `incus-testing.md`, `process-flowchart.md` and `ansible-venv.md`. For example, `ansible-playbook RESOLVE-base.yml -K` and `ansible-galaxy install -r RESOLVE-requirements.yml`.
- **Not changed:** the dated and versioned docs (now frozen in `artifacts/` by decision B), `CHANGELOG.md` and `OLD-README.md` still use the old names.

Checked: `ansible-playbook --syntax-check` passes for `bootstrap.yml` and `RESOLVE-base.yml`. The playbooks were not run against a server.

Note: proposed change 5 renames this playbook again, to `normalize.yml`.

### Decision B applied

Each historical doc was moved into an `artifacts/` folder next to its old location. A note was added at the top: line 1, or right after the closing `---` of the frontmatter, followed by a blank line.

```markdown
> Historical. Superseded by README v0.3.0.
```

| From | To |
|---|---|
| `en/docs/design/ansible-dev-design-v0-1-3-md` | `en/docs/design/artifacts/ansible-dev-design-v0-1-3-md` |
| `en/docs/design/incus-dev-design-v0.1.0.md` | `en/docs/design/artifacts/incus-dev-design-v0.1.0.md` |
| `en/docs/design/incus-dev-design-v0.1.1.md` | `en/docs/design/artifacts/incus-dev-design-v0.1.1.md` |
| `en/docs/design/augure-2026-11-07.md` | `en/docs/design/artifacts/augure-2026-11-07.md` |
| `en/docs/process-flowchart-v0.1.0.md` | `en/docs/artifacts/process-flowchart-v0.1.0.md` |
| `en/docs/process-flowchart-v0.1.1.md` | `en/docs/artifacts/process-flowchart-v0.1.1.md` |
| `en/docs/process-flowchart-v0.4.0-production.md` | `en/docs/artifacts/process-flowchart-v0.4.0-production.md` |
| `en/docs/process-flowchart-v0.4.1-production.md` | `en/docs/artifacts/process-flowchart-v0.4.1-production.md` |
| `en/docs/project-instructions-v0.1.0.md` | `en/docs/artifacts/project-instructions-v0.1.0.md` |
| `en/docs/project-instructions-v0.1.2.md` | `en/docs/artifacts/project-instructions-v0.1.2.md` |
| `en/docs/project-instructions-v0.1.3.md` | `en/docs/artifacts/project-instructions-v0.1.3.md` |
| `en/docs/names-augure-chat-2026-11-06.md` | `en/docs/artifacts/names-augure-chat-2026-11-06.md` |
| `en/docs/The chicken-and-egg, precisely stated.md` | `en/docs/artifacts/The chicken-and-egg, precisely stated.md` |
| `OLD-README.md` | `artifacts/OLD-README.md` |

What else changed:

- **Content unchanged** apart from the note, including the placeholder-hash notes in the v0.4.x flowcharts.
- **Audit report:** the placeholder-hash entry now gives the `en/docs/artifacts/` paths, so future scans check the right files.

Left where they are:

- `CHANGELOG.md`: it's the live changelog, not something the README replaces.
- `en/docs/decisions/*`: decision records already track their own status.
- `en/docs/README-layout.md`: not part of item 13.

Notes:

- `en/docs/design/` now holds only `artifacts/`.
- `en/docs/README-layout.md:8` and `en/docs/decisions/decision-zero-downtime-v0.1.0.md:50` mention `process-flowchart-v0.1.1.md` by name, which now sits under `artifacts/`. They are plain text, not links, so nothing breaks.
- The new `artifacts/` folders were added to the README's structure by decision D.

### Decision D applied

After the proposed tree was shown and confirmed, the README's Repository Structure section gained these entries:

| Added | Where in the tree |
|---|---|
| `CHANGELOG.md` | Repo root |
| `task-normalize-uc-gradus-repository-to-match-readme.md` | Repo root (later removed from the tree when the file moved to `en/docs/sessions/2026-11-07-2109-session-prompt.md`) |
| `test/incus/` with `launch.sh`, `quick-initial.sh` and `verify.sh` | Repo root |
| `artifacts/` | Repo root |
| `artifacts/`, `audits/`, `sessions/` | Under `en/docs/` |
| `artifacts/` | Under `en/docs/design/` |

What else changed:

- **Tree fix:** `design/` now sits beside `decisions/` under `en/docs/`, as on disk, instead of nested inside it. This resolves one of the decision C contradictions.
- **Unchanged:** the rest of the README, including `version: 0.3.0`. The "Superseded by README v0.3.0" notes in the artifacts refer to that version.

Still different from the actual layout (handled by proposed changes 1–7 and 10–11):

- The files are still under `ansible/`.
- `inventory/`, `playbooks/` and `scripts/gradus` don't exist yet.
- `bootstrap/`, `cloud-init/` and `tools/` aren't listed.

## 4. Open items

Security:

- [ ] If either original password hash was for a password in use, or was pasted anywhere else, change the admin password and update the vault.
- [ ] Make sure the vault password is long and random. In a public repository anyone can try to guess it offline.
- [ ] Decide whether the personal domains, chat transcripts and live public keys (finding 3) should be public.
- [ ] Point `ansible/inventory.ini` at the real server before the first production run (finding 4).
- [ ] Rename the key files on the laptop to the new names, or the scripts and playbooks won't find them.
- [ ] Optional: install gitleaks as a pre-commit hook, and tell it to skip the placeholder hash in `.gitleaks.toml`.

README audit:

- [x] Decision A: conflicting files renamed to `RESOLVE-<code-file-name>`.
- [ ] For each `RESOLVE-` file, choose between the README's robertdebock role and changing the README's role list.
- [x] Decision B: historical docs frozen in `artifacts/` folders with the "Historical" note.
- [x] Decision D: listed files and folders added to the README's structure, with the `decisions`/`design` nesting fixed.
- [ ] Decide the remaining decision C contradictions. Then the final change table for changes 1–12 will be shown and applied on confirmation.

## 5. Remaining task items: to implement during the end-to-end dev run

The task in [`2026-11-07-2109-session-prompt.md`](2026-11-07-2109-session-prompt.md) is **not complete**. Done so far:

- the audit and its findings
- decisions A, B and D
- SSH key names
- change 13

**Plan (owner's decision, 2026-11-07):** implement the remaining changes while running the whole dev process from beginning to end (raw → onboard → normalize → caddy-server), so each change is tested as it lands. Each change will still be shown in a change table and applied on confirmation, as the task requires.

| # | Change | Status | Blocked by decision C? |
|---|---|---|---|
| 1 | Move `ansible.cfg`, `group_vars/` and the playbooks out of `ansible/` to the root layout | Not done | No |
| 2 | `inventory/{dev,stage,prod}/hosts.ini`, group `[targets]`, plus `inventory/dev/group_vars/targets.yml` | Not done | No |
| 3 | Move the vault under `targets` | Not done | No |
| 4 | `ansible/bootstrap.yml` becomes `playbooks/onboarding.yml` | Not done | Partly: who removes the out-of-box user |
| 5 | `ansible/RESOLVE-base.yml` becomes `playbooks/normalize.yml`, with Caddy taken out | Not done | Partly: the README's "monitoring" and "cron" |
| 6 | Create `playbooks/caddy-server.yml` with the Caddy tasks from the base playbook | Not done | No |
| 7 | `scripts/gradus` stub (`onboard`, `normalize`, `roles list`, `roles apply N`) | Not done | Partly: the `--env` flag |
| 8 | Variable names (`ssh_admin_key`/`ssh_deploy_key` vs `admin_pubkey`/`deploy_pubkey`) | Not done | Yes |
| 9 | Role list: for each `RESOLVE-` file, the README's robertdebock role or a change to the README's list | Files marked only | Owner's choice |
| 10 | `# OUT OF SCOPE — not in README v0.3.0` on `bootstrap/bootstrap.sh` and `cloud-init/user-data.yaml` | Not done | No |
| 11 | `# OUT OF SCOPE — not in README v0.3.0` on `tools/make-ansible-venv.sh` | Not done (the `test/incus/` part is done) | No |
| 12 | Update the current docs (`initial-setup.md`, `incus-testing.md`, `process-flowchart.md`, `ansible-venv.md`) to the new commands and paths | Not done; waits on 1–7 | Indirectly |

Decision C contradictions still open, to settle when the run reaches them:

- The README's naming table has no `raw` environment or `initial` purpose, but the keypair inventory lists `gradus-raw-initial-id_ed25519`.
- Commands has no `--env` flag; Testing uses `--env dev`.
- Testing restores a `pre-onboard` snapshot that nothing creates; `launch.sh` creates `fresh`.
- Quick Start says onboarding removes the out-of-box user; today normalize does it, because onboarding runs as that user.
- Normalize is described as setting up "monitoring" and "cron", which don't exist.

## 6. Session files

The task prompt was moved into this folder and named after the time work on it began:

| From | To |
|---|---|
| `task-normalize-uc-gradus-repository-to-match-readme.md` (repo root) | `en/docs/sessions/2026-11-07-2109-session-prompt.md` |

- **Timestamp:** 21:09 EST, the time the prompt "have a look at task-normalize…" was sent (02:09:15 UTC in the session transcript). That fits the other times: the memory note just before it was saved at 21:02, and this report was started at 21:13.
- **Content:** unchanged.
- **README:** the task file's line was removed from the repo root in the Repository Structure section. The existing `en/docs/sessions/` entry now covers it.
- **This report:** the "Task file" link (section 3) and the section 5 reference point to the new name.
- **Not updated:** the owner's copy, `2026-11-07-2113-session-report-responses.md`, still links to the old root path, so that link is broken.

Files in `en/docs/sessions/`:

| File | What it is |
|---|---|
| `2026-11-07-2109-session-prompt.md` | The task prompt: normalize the repository to match `README.md` |
| `2026-11-07-2113-session-report.md` | This report |
| `2026-11-07-2113-session-report-responses.md` | The owner's copy of an earlier version of this report, with the decision A response |

## 7. Session process

The owner adopted this session's way of working as the standard for Claude Code CLI sessions: "so that will be the process for our claude cli sessions". The question was where to keep the process prompt. The recommendation was a root `CLAUDE.md`, because Claude Code loads it in every session in the repository and it is versioned with the code. Claude's memory notes, by contrast, are private to one machine.

The owner asked: "create CLAUDE.md and create a new process in uc-process regarding this process".

| File | Change |
|---|---|
| `CLAUDE.md` (new, repo root) | Session files and timestamps, how changes are made (findings table first, apply on confirmation, stay in scope, record decisions word for word, open items), and conventions (README is the source of truth, `artifacts/` for historical files, no secrets in reports, no commits unless asked). Links to the uc-processes process |
| `README.md` | `CLAUDE.md` added to the Repository Structure, after `README.md` |
| `../uc-processes/en/docs/processes/running-a-claude-code-session-v0.1.0.md` (new) | *Process: Running a Claude Code Session*, version 0.1.0, Draft. It follows the format of the other uc-processes processes: Dublin Core front matter with a new UUID, steps that each end in a "Gate:" line, Principles, Changelog and the CC BY 4.0 licence. Its examples come from this session |

Notes:

- The repository was taken to be `uc-processes`; there is no `uc-process`.
- uc-processes has uncommitted work in progress, which looks like moving `en-ca/` to `en/`. The new process went into `en/docs/processes/`, and nothing else there was touched.
- **Not done:** the `[Unreleased]` entry in `uc-processes/CHANGELOG.md`. The `permissions.blockReadsOutsideWorkingDirectories` setting blocks editing files outside uc-gradus, so the entry is left for the owner:

  ```markdown
  ### Added

  - Process: Running a Claude Code Session, version 0.1.0, in draft, under `en/docs/processes/`.
  ```

- **Not done:** the uc-processes README's Processes table lists only one process and links to `en-ca/` paths. It was left alone because that repository is mid-move.

Open items from this section:

- [x] Add the changelog entry above to `uc-processes/CHANGELOG.md`. Done after the owner ran `/add-dir ../uc-processes`.
- [ ] Optionally list the new process in the uc-processes README's Processes table, once the `en-ca/` to `en/` move is settled.

## 8. Release ceremony, documented in uc-processes

From this session, the owner asked whether the release ceremony meant for each new repository was documented in uc-processes. It was not. Its own session records are in uc-processes, where process work belongs:

- Prompt: `uc-processes/en/docs/sessions/2026-11-07-2209-session-prompt.md`
- Report: `uc-processes/en/docs/sessions/2026-11-07-2216-session-report.md`, with the findings, the owner's decisions word for word, and what was applied

The owner's direction during that work:

> since we are effectivly moving process "creation & documentation" to uc-processes, where the work happens on processes. that is where we want to document what we have now regarding releases and release processes. So that part is for those roadmaps and changelogs.

In short, by repository:

| Repository | File | Change |
|---|---|---|
| uc-processes | `en/docs/processes/releasing-a-repository-v0.1.0.md` | New: *Process: Releasing a Repository* 0.1.0, Draft. It follows the ceremony decided in uc-automa 0026, 0028, 0030 and 0032, with a hand-cut path until uc-automa 0.3.0 (uc-automa 0039). The release key's principal is a decision still to make |
| uc-processes | `ROADMAP.md` | New: the open items from the release process |
| uc-processes | `CHANGELOG.md` | `[Unreleased]` gained bullets for the release process and `ROADMAP.md` |
| uc-automa | `ROADMAP.md` | One bullet under "Next release": decide the allowed-signers principal before `release-keys/` is created. The owner chose to keep it: "keep the uc-automa roadmap bullet" |

Nothing in uc-gradus changed for this work.

What it means for uc-gradus: uc-gradus has no `VERSION` file and no release ceremony yet. When it is first released, *Process: Releasing a Repository* applies.

Open items:

- [ ] Decide the release key's allowed-signers principal, as a decision record in uc-automa.
- [ ] The rest of `uc-processes/ROADMAP.md` "Later", most of which waits on uc-automa 0.3.0.

## 9. Commits

The owner asked: "commit the changes in all three repos". Asked whether to branch first, the owner confirmed committing to each repository's own `main`: "Do you mean the changes repo a will be in the main of repo a. If so proceed".

Before committing, uc-gradus's history was checked: its initial commit `f7e96ae` (2026-11-07 21:10, by the owner) holds neither of the original password hashes. The only old value it holds is the key file name `chris_steel_personal_id_ed25519`, quoted by the secrets audit as part of finding 3.

| Repository | Commit | What it holds |
|---|---|---|
| uc-gradus | `26e7566` Normalize to README: RESOLVE- renames, artifacts, session records, CLAUDE.md | All of this session's changes: 22 renames or moves, 11 modified files, 3 new files |
| uc-processes | `d60b25b` Add release and Claude Code session processes, ROADMAP | Only this session's files: `CHANGELOG.md`, `ROADMAP.md`, `en/docs/processes/releasing-a-repository-v0.1.0.md`, `en/docs/processes/running-a-claude-code-session-v0.1.0.md`, and the two session files |
| uc-automa | `a76b8e9` Roadmap: decide the allowed-signers principal before release-keys/ | Only `ROADMAP.md`, one line, committed with `git commit -- ROADMAP.md` |

Left uncommitted, because it is the owner's work in progress:

- **uc-processes:** the `en-ca/` → `en/` move. The owner did not choose between committing only Claude's files and including the move, so only Claude's files were committed. Until the move is committed, the release process's links to `en/docs/guides/` and to other `en/docs/processes/` files don't resolve in history. The commit message says so.
- **uc-automa:** the staged `.gitignore`, an overview rename and a new session note stay staged, and were not part of the commit.

The report updates recording these commits are uc-gradus `eeb8cfa` and uc-processes `a6b8c10`.

### Pushes

The owner asked: "push all three repos". Each repository was 2 commits ahead of `origin/main` and 0 behind, so each push was a fast-forward:

| Repository | Pushed | Notes |
|---|---|---|
| uc-gradus | `f7e96ae..eeb8cfa` | |
| uc-processes | `206f00e..a6b8c10` | |
| uc-automa | `20e7fad..a76b8e9` | It also carried the owner's earlier unpushed commit `218bdec`. A push hook in that repository also pushed "2 checkpoint ref(s)" |

After each push, `main` and `origin/main` matched. The owner's uncommitted work stayed local.

Then the owner asked: "update the session reports, commit and push them, lol". This update to both reports was committed and pushed the same way, and is not recorded again.

### Committing everything

The owner asked: "lets commit everything". Only uc-processes and uc-automa had uncommitted work left:

| Repository | Commit | What it holds |
|---|---|---|
| uc-processes | `5a38160` | The owner's *Process: Creating an Eleventy Theme* 0.1.0. `CHANGELOG.md` gained entries for it and for the `en-ca/` → `en/` move |
| uc-automa | `c9e4ea3` | The owner's `en-ca/` → `en/` move (77 renames), the `.gitignore` change, an overview rename, a session note, and a new `ROADMAP.md` item |

uc-automa's tests were run before committing: 45 tests, 1 failure on the previous commit and 2 with the move. The new failure, `test_translations_report_nothing_for_en_ca`, is because the code still uses `en-ca` as its default language. The owner's call: "sounds like a roadmap issue for updating our script". So the move was committed with the failure stated in its commit message, and `uc-automa/ROADMAP.md` "Later" gained an item: a decision record superseding 0004, then the code, tests and fixtures updated to `en/`. The other failure, `test_check_passes_on_uc_automa`, was already failing and wasn't investigated.

Then the owner asked: "update the session reports and push all three repos". This update and the pushes are not recorded again.

Open items:

- [ ] uc-automa: follow the `en/` move in the code (roadmap, "Later").
- [ ] uc-automa: find out why `test_check_passes_on_uc_automa` was already failing.

Open items:

- [x] Commit the `en-ca/` → `en/` move in uc-processes. The owner asked: "commit and push the en-ca to en move in uc-processes". It is uc-processes `25a06df`, pushed, with the README's link moved to match. The details are in uc-processes' session report.
- [x] Push all three repositories.

## Observations left out of scope

These came up during the session and were deliberately left alone, because the work was limited to security fixes:

- `initial_ssh_key` is used by `bootstrap.yml`, but its only definition, in `ansible/group_vars/all.yml`, is commented out.
- `ansible/group_vars/all.yml:18` has a commented-out `admin_ssh_key` line that now matches the live line below it.

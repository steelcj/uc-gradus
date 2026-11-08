---
name: uc-gradus-normalize-prompt
org: universal-cake
lang: en
type: prompt
version: 1.0.0
date: 2026-11-07
---

# Task: Normalize uc-gradus repository to match README.md

## Source of truth

README.md is the authoritative specification. All files in this repository
must conform to it. If a file contradicts the README, the file is wrong.

## Your job

Audit every file in this repository against README.md. For each discrepancy,
report it and propose a fix. Do not make changes silently, present findings
first, then apply corrections on confirmation.

## Conventions to enforce

| Convention | Authority |
|---|---|
| CLI commands are `gradus onboard`, `gradus normalize`, `gradus roles list`, `gradus roles apply` | README § Commands |
| Playbooks are `onboarding.yml`, `normalize.yml`, `caddy-server.yml` | README § Minimal Example |
| SSH keypairs follow `gradus-<env>-<purpose>-<algorithm>` naming | README § SSH Keypairs |
| Environments are `dev`, `stage`, `prod` selected by inventory directory | README § Configuration |
| Target OS is Debian 13 | README § Prerequisites |
| Robertdebock roles as listed in README § Prerequisites | README § Prerequisites |
| Repository structure matches README § Repository Structure | README § Repository Structure |
| No containers, no orchestration, no Kubernetes | README § Scope |

## Rules

1. Do not invent new files, directories, or features not described in the README.
2. Do not expand scope beyond the short stack (Caddy, rsync, Debian 13, static sites).
3. If a file references a command, playbook, key, or path that contradicts the
 README, correct it to match the README.
4. If the README references something that does not exist yet, create it as a
 minimal stub with a TODO comment. Do not implement functionality beyond
  what the README describes.
5. Preserve existing working code. Only change what conflicts with the README.
6. Present a summary table of changes before applying them:

| File | Current | Required | Action |
|---|---|---|---|

## Scope boundary

The first iteration delivers: raw → normalized → caddy-server (static site).
Nothing else. If you find files that suggest additional roles, services,
or integrations, flag them as out-of-scope but do not delete them — mark
them with a comment `# OUT OF SCOPE — not in README v0.3.0`.

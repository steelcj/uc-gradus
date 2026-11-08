# Pre-publication secrets audit

- Date: 2026-11-07
- Scope: every file in the working tree that git would track (`git ls-files -co --exclude-standard`), plus ignored paths checked to confirm they stay out
- Repository state: branch `main`, no commits yet, remote `https://github.com/steelcj/uc-gradus`
- Method: manual pattern search (no secret scanner such as gitleaks or trufflehog was installed), followed by review of every hit in context

This report deliberately does not reproduce any secret values. Findings point to file and line only.

## Summary

| # | Severity | Finding | Action |
|---|----------|---------|--------|
| 1 | High | Admin password hashes pasted in plain text in the docs | **Fixed 2026-11-07**: replaced with a placeholder hash. Change the password if either original was in use |
| 2 | Low | Stray file `ansible/deploy@10.119.134.236` | **Fixed 2026-11-07**: deleted |
| 3 | Info | Personal identifiers (domains, key file name, chat transcripts) | Owner's decision |
| 4 | Info | `inventory.ini` points `web1` at the Incus test container | Check before the first real deploy |

Nothing has been exposed yet: `main` has no commits, so every finding can be fixed before the first push.

## Findings

### 1. Password hashes in documentation (High)

Two different yescrypt hashes (`$y$j9T$...`) appear in full:

| Hash (salt prefix) | Locations | Context |
|--------------------|-----------|---------|
| `BeA9…` | `en/docs/process-flowchart-v0.4.0-production.md:73`, `en/docs/process-flowchart-v0.4.1-production.md:72` | "Paste in the password hash", in the production guide, so this is probably the real admin password hash |
| `ROc/…` | `en/docs/initial-setup.md:117`, `en/docs/initial-setup.md:131` | Labelled "Example output"; may or may not be a real password |

Why it matters: the hash is only ever supposed to live in `ansible/group_vars/web/vault.yml`, which is encrypted. A plain-text copy in the docs bypasses the vault. Anyone with the hash can try to guess the password offline. yescrypt makes each guess slow, but a short or common password will still fall.

Remediation:

1. Replace each hash with a placeholder such as `'$y$j9T$...'`.
2. If either hash belongs to a password in use, or was pasted anywhere else (chat, issue tracker, paste site), set a new admin password, regenerate the hash with `mkpasswd -m yescrypt`, and update the vault with `ansible-vault edit group_vars/web/vault.yml`.

Resolution (2026-11-07): all four occurrences now use one placeholder hash, generated from the password `example`:

```text
$y$j9T$k.rs2L0nJjhJAmRNu5CtE0$CUGlgkyoMbSFNdxWQorRG6VTxhqHVm2hTOIKQ7YBtEC
```

A "Placeholder hash" note follows each occurrence, so a reader or a future scan can tell it is not a real credential. The missing space after the colon in the v0.4.0 line (`admin_password_hash:'...'`, which YAML does not read as a key) was fixed at the same time. Step 2 still applies if either original hash was a real password.

### 2. Stray file `ansible/deploy@10.119.134.236` (Low)

The file contains only the word `flow`, so it was probably created by a mistyped command. It holds no secret, but it puts a host address into the repository and serves no purpose.

Remediation: delete the file.

Resolution (2026-11-07): deleted.

### 3. Personal identifiers (Info)

None of these are secrets. Whether they belong in a public repository is the owner's decision.

- Personal domains `balise.chrissteel.com` and `chris.steel.com`: `README.md:202`, `en/docs/project-instructions-v0.1.2.md:24-25,78`, `en/docs/project-instructions-v0.1.3.md:42-43`, `en/docs/names-augure-chat-2026-11-06.md:90,123-124,177`
- A personal key file name: `en/docs/incus-testing.md:58` used `~/.ssh/chris_steel_personal_id_ed25519`. **Fixed 2026-11-07**: every key name in the repository now follows the `gradus-{raw|dev|stage|prod}-{initial|admin|deploy}-id_ed25519` scheme, and this one became `~/.ssh/gradus-raw-initial-id_ed25519`.
- Chat transcripts `en/docs/names-augure-chat-2026-11-06.md` and `en/docs/design/augure-2026-11-07.md` include planning notes: the DNS provider (Namecheap), hostnames and future plans.
- Live public SSH keys (`admin@laptop`, `deploy@ci`) in `ansible/group_vars/all.yml:12-13` and the v0.4.x production docs. Public keys do not grant access, but publishing them lets people link the servers that accept them to their owner.

### 4. Inventory points at the test container (Info)

`ansible/inventory.ini:2-3` says to replace the documentation address `203.0.113.10` with the real server's address. The active line, `web1 ansible_host=10.119.134.236`, is the Incus test container instead. This is not a secret, but check the file before the first production run.

## Reviewed and acceptable

- **`ansible/group_vars/web/vault.yml`** is Ansible Vault (AES256) encrypted, so committing it is the intended setup. In a public repository anyone can try to guess the vault password offline, so it must be long and random. No vault password file is present in the repository.
- **Private keys under `ansible/roles/`** (`robertdebock.users/molecule/default/ssh_keys/keyuser`, `privkeyuser` and their `.ppk` files) are test keys that ship with the upstream role. `.gitignore` excludes `ansible/roles/`, and `git check-ignore` confirms these files are ignored.
- **`test/incus/inventory.ini`** is gitignored and is not present.
- **No API tokens or cloud credentials found.** The search covered GitHub (`ghp_`, `gho_`, `github_pat_`), GitLab (`glpat-`), Slack (`xox?-`), AWS (`AKIA…`), Google (`AIza…`), OpenAI and Anthropic (`sk-`, `sk-ant-`), bearer tokens, and `BEGIN … PRIVATE KEY` blocks.
- **The placeholder yescrypt hash** `$y$j9T$k.rs2L0nJjhJAmRNu5CtE0$...` (password `example`) in `en/docs/initial-setup.md` and `en/docs/process-flowchart-v0.4.{0,1}-production.md` is intentional, and a note sits next to each copy. Future scans should treat it as a known false positive.
- **Placeholder values** such as `REPLACE_WITH_YESCRYPT_HASH` in `ansible/group_vars/all.yml` and `cloud-init/user-data.yaml`, `DEV_HASH_HERE`, `AAAAI_DEV_ADMIN`, and `'your-vault-password'` in `en/docs/incus-testing.md:126` are intentional.
- **IP addresses** are all private (Incus `10.119.134.0/24`, `10.10.10.0/24`, `10.20.30.0/24`, `fd42:` addresses), loopback, or documentation-only (`203.0.113.0/24`).
- **`~/.ssh/...` paths** throughout the docs name key files but contain no key material.

## Recommendations

1. Fix findings 1 and 2 before the first commit.
2. Install a scanner (for example gitleaks) and add it as a pre-commit hook, so a hash or key cannot slip into a commit unnoticed.
3. Add a docs convention: example hashes and keys must use obvious placeholders (`$y$j9T$...`, `AAAAC3Nza...`), never real output.

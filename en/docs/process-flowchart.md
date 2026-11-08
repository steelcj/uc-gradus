# Process flowcharts

These charts show how the pieces of ex2-base fit together, from preparing the laptop to deploying a site. Each box names the document or script that covers the step: `docs/ansible-venv.md`, `docs/initial-setup.md`, `docs/incus-testing.md` and the scripts in `test/incus/`. The charts use Mermaid, which GitHub and most Markdown viewers render as diagrams.

## Overview

The same procedure runs twice: first against a local Incus stand-in on flow, then against the real Ex2 server. Only the inventory differs.

```mermaid
flowchart TD
    A["Prepare flow<br/>Ansible venv, tools, keypairs, vault"] --> B["Rehearse on Incus<br/>docs/incus-testing.md"]
    B --> C{"Rehearsal clean?<br/>verify PASS, changed=0,<br/>reboot and lockout drill OK"}
    C -- "No" --> D["Fix, then restore<br/>snapshot fresh"]
    D --> B
    C -- "Yes" --> E["Order Ex2 server<br/>Debian 13, key for root"]
    E --> F["First session on Ex2<br/>docs/initial-setup.md"]
    F --> G["Verify from outside<br/>verify.sh against the VPS"]
    G --> H{"All PASS?"}
    H -- "No" --> I["Troubleshoot<br/>console is the fallback"]
    I --> F
    H -- "Yes" --> J["Snapshot, if Ex2 offers it"]
    J --> K["Deploy sites<br/>rsync as deploy into /srv/sites"]
    K --> L["Ongoing<br/>re-run RESOLVE-base.yml to correct drift,<br/>unattended-upgrades for security"]
```

## Preparing flow

Done once, and again when the Ansible pin or the keys change.

```mermaid
flowchart TD
    A["Activate or build the venv<br/>./tools/make-ansible-venv.sh"] --> B[". ~/.venvs/ansible/current/bin/activate"]
    B --> C["Install roles<br/>ansible-galaxy install -r RESOLVE-requirements.yml"]
    C --> D["Make three keypairs<br/>gradus-raw-initial-id_ed25519, gradus-prod-admin-id_ed25519, gradus-prod-deploy-id_ed25519"]
    D --> E["Public keys into<br/>group_vars/all.yml"]
    E --> F["Admin password hash<br/>mkpasswd -m yescrypt"]
    F --> G["Vault it<br/>ansible-vault create group_vars/web/vault.yml"]
    G --> H{"Testing locally?"}
    H -- "Yes" --> I["Host prep on flow<br/>nftables modules loaded"]
    I --> J["./test/incus/launch.sh<br/>writes test/incus/inventory.ini,<br/>snapshot fresh"]
    H -- "No, real server" --> K["Put the Ex2 IPv4 in<br/>ansible/inventory.ini"]
```

## First session

The same steps on the Incus stand-in and on Ex2. On Incus, the console is `incus exec` or `incus console`, and every playbook command adds `-i ../test/incus/inventory.ini`.

```mermaid
flowchart TD
    A["Log in as root<br/>ssh with gradus-raw-initial-id_ed25519 key, or console"] --> B["Update system<br/>install sudo, rsync, python3"]
    B --> C["Create initial<br/>sudo group, password, key"]
    C --> D{"ssh initial@server works<br/>and sudo -v OK?"}
    D -- "No" --> C
    D -- "Yes" --> E["As initial: shut root out<br/>lock root password,<br/>10-hardening.conf, restart ssh"]
    E --> F{"ssh root@server refused?"}
    F -- "No" --> E
    F -- "Yes" --> G["bootstrap.yml as initial<br/>-u initial -K --ask-vault-pass"]
    G --> G1["robertdebock.bootstrap<br/>python3, sudo, python3-apt"]
    G1 --> G2["Umask policy<br/>027, homes 0700"]
    G2 --> G3["robertdebock.users<br/>admin and deploy"]
    G3 --> G4["Deploy key, root-owned,<br/>rrsync to /srv/sites"]
    G4 --> H{"admin logs in and sudo works?<br/>deploy key gets no shell?"}
    H -- "No" --> T["Troubleshooting in<br/>docs/incus-testing.md"]
    T --> G
    H -- "Yes" --> I["Log out every initial session"]
    I --> J["RESOLVE-base.yml as admin<br/>-K --ask-vault-pass"]
    J --> J1["Packages, Caddy from backports"]
    J1 --> J2["nftables before sshd"]
    J2 --> J3["sshd hardening<br/>AllowUsers admin deploy"]
    J3 --> J4["sshguard, unattended-upgrades,<br/>journald cap, resolved LLMNR off"]
    J4 --> J5["Delete initial"]
    J5 --> J6{"Listener audit passes?<br/>only sshd and Caddy public"}
    J6 -- "No" --> T
    J6 -- "Yes" --> K["Remove gradus-raw-initial-id_ed25519 key<br/>from the laptop"]
```

## Verify and recovery

After the first session, and again after any change to the playbooks.

```mermaid
flowchart TD
    A["./test/incus/verify.sh address"] --> B{"admin logs in?"}
    B -- "No" --> R["Recover without SSH<br/>console, or incus exec"]
    B -- "Yes" --> C{"All checks PASS?<br/>refusals, rsync, Caddy, ports"}
    C -- "No" --> T["Troubleshooting<br/>check sshguard block,<br/>IdentitiesOnly, whitelist"]
    T --> A
    C -- "Yes" --> D["audit-listeners.sh as admin"]
    D --> E["Run RESOLVE-base.yml again"]
    E --> F{"changed=0?"}
    F -- "No" --> G["Fix the task that<br/>changes every run"]
    G --> E
    F -- "Yes" --> H["Reboot<br/>incus restart, then verify.sh"]
    H --> I{"Everything back by itself?"}
    I -- "No" --> T
    I -- "Yes" --> J["Lockout drill<br/>DenyUsers admin in 05-break.conf"]
    J --> K{"New admin login refused?"}
    K -- "No" --> J
    K -- "Yes" --> R
    R --> L["Remove 05-break.conf,<br/>restart ssh"]
    L --> M{"admin-ok?"}
    M -- "No" --> R
    M -- "Yes" --> N["Ready for Ex2,<br/>or for the next change"]
```

## Deploying a site

Once the server is in place, every publish is one rsync as `deploy`.

```mermaid
flowchart TD
    A["Build the site locally or in CI"] --> B["rsync -rlt --delete --chmod=D755,F644<br/>with the gradus-prod-deploy-id_ed25519 key"]
    B --> C["rrsync confines it to /srv/sites"]
    C --> D["Files land in /srv/sites/site-name/"]
    D --> E{"Site block in Caddyfile?"}
    E -- "No" --> F["As admin: add the site block,<br/>chmod 644 Caddyfile,<br/>systemctl reload caddy"]
    F --> G["Caddy gets the certificate<br/>and serves HTTPS on 443"]
    E -- "Yes" --> G
```

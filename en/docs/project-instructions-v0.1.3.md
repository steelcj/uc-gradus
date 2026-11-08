# UC-Gradus — Static Website Hosting Pipeline

> *One artifact, ascending trust.*

## Organization

**Universal Cake** — umbrella brand for all projects.

| Project | Purpose |
|---------|---------|
| UC-Gradus | Static website hosting pipeline (this project) |
| Cake Metrics | Monitoring & alerting |

## Objective

Build a lightweight, secure "short stack" for hosting multiple static websites
in production, with a fast local testing environment using Incus + btrfs.

## Architecture

| Layer | Environment | Technology | Rationale |
|-------|-------------|------------|-----------|
| Testing | Local Incus containers | Debian 13, btrfs pool, bridged network | COW snapshots, machine-like speed, rapid iteration |
| Production | KVM VMs | Debian 13 (minimal) | Isolation, low attack surface, hosting-compatible |
| Web server | Both | Caddy | Auto-HTTPS via built-in ACME, multi-site routing |
| DNS | Namecheap (near-term) | Caddy's built-in ACME | Automated TLS issuance/renewal |
| Site builder | Local machine | Eleventy (default), Hugo (supported) | Outputs prebuilt HTML in `site/` |
| Deployment | Local → server | rsync (with permission handling) | Incremental, auditable, simple |

## Core Principle

**Build once. Validate. Promote. Never rebuild.**

The same verified artifact moves through every environment. Each stage adds
trust. An explicit gate authorizes promotion to the next level.

## Multi-Tenancy Model

One shared VM per production node. Caddy routes by `Host` header to distinct
site directories. Example:

- Server hostname: `balise.chrissteel.com`
- Site A: `chris.steel.com` → `/srv/sites/chris-steel-com/site/`
- Site B: `another.example.com` → `/srv/sites/another-example-com/site/`

Each site is independently built and deployed via rsync.

## Lifecycle (Start → Finish)

| Phase | Scope |
|-------|-------|
| 1. Provision | Storage pools, base images, networking (Incus bridged; KVM VM) |
| 2. Harden | Minimal Debian 13, SSH, firewall, user/group baseline |
| 3. Serve | Caddy install, multi-site config, DNS gate, ACME/TLS validation |
| 4. Deploy | Build locally → rsync `site/` → permissions → smoke test |
| 5. Operate | Snapshots (testing), manual updates, cert alerting, monitoring (TBD) |

## Testing Strategy

1. Develop automation scripts against Incus container (Debian 13, btrfs)
2. Snapshot before each test run — rollback freely
3. Once automation passes: snapshot the **configured** container (Caddy certs,
 configs tuned for test environment)
4. Use that golden snapshot as the starting point for site-deployment tests
5. Production deployment follows the same scripts, pointed at the KVM VM

## Update & Maintenance Policy

| Timeframe | Approach |
|-----------|----------|
| Now | Manual patching (`apt upgrade`), scripted where possible |
| Near-term | unattended-upgrades or equivalent |
| Future | Immutable OS (NixOS?) if hosting supports custom ISOs |

Priority: get things running safely ASAP. Harden the OS strategy later.

## Monitoring

TBD — pending definition of Cake Metrics. Flowcharts include a
placeholder node.

## Naming & Conventions

| Convention | Pattern | Example |
|------------|---------|---------|
| Project name (prose) | UC-Gradus | "UC-Gradus handles deployment" |
| Project name (repos, slugs) | uc-gradus | `universal-cake/uc-gradus` |
| CLI command | `gradus` | `gradus deploy`, `gradus snapshot` |
| Document filenames | `<slug>-vN.N.N.md` | `process-flowchart-v0.1.1.md` |
| Doc versioning | Bump patch/minor per edit; graduate to v1.0.0 when stable | |
| Flowcharts | Mermaid inside Markdown | |
| Decision records | `decision-<topic>-vN.N.N.md` in `en/docs/decisions/` | |
| Language | English docs in `en/docs/` | |

## Directory Structure

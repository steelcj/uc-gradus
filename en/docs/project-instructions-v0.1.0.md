# Short Stack — Static Website Hosting

## Objective

Build a lightweight, secure "short stack" for hosting multiple static websites
in production, with a fast local testing environment.

## Architecture

| Layer | Environment | Technology | Rationale |
|-------|-------------|------------|-----------|
| Testing | Local Incus containers | btrfs storage pool | Machine-like speed, COW snapshots for rapid iteration |
| Production | KVM virtual machines | TBD host OS | Isolation, minimal attack surface |
| Web server | Both | Caddy | Auto-HTTPS, reverse proxy, minimal config |

## Scope: Start → Finish

The flowcharts must cover the full lifecycle:

1. **Provision resources** — storage pools, networking, base images
2. **Hardened host OS setup** — minimal install, security baseline
3. **Caddy installation & configuration** — multi-site, TLS, headers
4. **Site deployment** — build → transfer → serve (multiple sites)
5. **Operations** — backups, updates, monitoring

## Workflow

1. Draft Mermaid flowcharts covering every step above
2. Review for completeness (breadth check)
3. Convert confirmed flowcharts into linked "menu items" pointing into docs
4. Each flowchart lives in `en/docs/`

## Conventions

- **Versioning:** Any modified document is recreated as a new file using
 `<slug>-vN.N.N.md` (e.g. `process-flowchart-v0.1.0.md`).
  Never overwrite the original.
- **Flowchart format:** Mermaid inside Markdown.
- **Language:** English docs in `en/docs/`.

## Open Decisions (need answers before flowcharts are complete)

These affect which nodes appear in the diagrams:

| # | Question | Options to consider | Impact on flowchart |
|---|----------|---------------------|---------------------|
| 1 | Host OS choice for KVM VMs | Alpine, Debian minimal, Fedora CoreOS, Flatcar? | Determines package manager, init system, hardening steps |
| 2 | How are sites deployed? | rsync/scp, git push + hook, CI pipeline, container image? | Changes the "deploy" branch entirely |
| 3 | Multi-tenancy model | One Caddy per VM? One VM per site? Shared VM with path routing? | Networking + resource provisioning steps |
| 4 | DNS & TLS strategy | Cloudflare proxy, Caddy's built-in ACME, manual certs? | TLS provisioning nodes |
| 5 | Backup strategy | btrfs snapshots, external offsite, both? | Operations branch |
| 6 | Update/patch cadence | Manual, unattended-upgrades equivalent, immutable OS? | Maintenance loop in ops flowchart |
| 7 | Monitoring/logging | None, journald + grep, Prometheus node-exporter, Uptime Kuma? | Adds ops nodes |
| 8 | Incus networking model | Bridged, routed, OVN? | Provisioning nodes differ |
| 9 | Site source format | Pre-built HTML directories? Hugo/Jekyll output? SPA with fallback? | Deployment transfer logic |

## Next Step

Answer the open decisions (even rough preferences are fine), then I'll draft
the master flowchart and sub-flowcharts as `process-flowchart-v0.1.0.md`.
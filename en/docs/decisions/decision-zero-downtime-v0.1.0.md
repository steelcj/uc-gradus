{"title": "decision-zero-downtime-v0.1.0", "format": "md"}
# Decision Record: Zero-Downtime Deploy

## Status: Accepted

## Date: 2026-11-06

## Context

The deploy flow uses `rsync` to overwrite files in-place under
`/srv/sites/<domain>/site/`. This means there is a brief window (typically
milliseconds to a few seconds) where files are partially updated — a visitor
requesting a CSS file mid-sync might get a 404 or a truncated response.

## Decision

In-place rsync replacement is **acceptable** for this stack. No atomic
swap or symlink-swap mechanism is implemented.

## Rationale

1. **Static files are tiny.** Eleventy/Hugo output is HTML, CSS, JS, images.
 A full site sync completes in well under a second on LAN, and a few seconds
  over WAN.
2. **Traffic is negligible.** These are personal/small-business sites. The
 probability of a concurrent hit during the sync window is near zero.
3. **Simplicity wins.** Atomic swap (build to `site.new/`, then
 `mv site site.old && mv site.new site`) adds complexity to the rsync script
  and introduces edge cases with Caddy's file handles.
4. **Caddy handles 404s gracefully.** Even if a file is momentarily missing,
 the browser retries on refresh. No data loss.

## Trade-offs accepted

| Risk                               | Likelihood              | Impact                            |
| ---------------------------------- | ----------------------- | --------------------------------- |
| Visitor sees broken asset mid-sync | Very low                | Cosmetic, self-healing on refresh |
| Partial sync leaves mixed versions | Very low (network drop) | Next deploy fixes it              |
| Caddy serves stale file briefly    | Negligible              | Irrelevant for static content     |

## Revisit triggers

- Sites grow beyond ~50 MB total (sync window > 5 s)
- Traffic increases enough to make concurrent-hit probability non-trivial
- A deploy script is adopted that could incorporate `--delete` atomically
 (e.g., `rsync --link-dest` into a temp dir, then `rename()`)

## Related

- Phase 4 in `process-flowchart-v0.1.1.md`
- Existing rsync automation scripts
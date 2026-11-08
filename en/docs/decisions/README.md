# Decisions README.md

## Why separate folder

- **Decision records are "why" documents** — they have a lifecycle (proposed → accepted → superseded) that operational docs don't. Mixing them with how-to guides makes the menu harder to reason about.
- **They're cross-cutting.** `decision-zero-downtime` affects the deploy flowchart AND the operate phase. Co-locating it under one phase folder creates ambiguity about ownership.
- **Menu linking stays clean.** When you build the menu system, each folder becomes a category: Flowcharts | Decisions | Guides. The `index.md` can enumerate them without parsing filenames for type hints.
- **Supersession chains are obvious.** When `decision-host-os-v0.1.0.md` (Debian) is eventually replaced by `decision-host-os-v0.2.0.md` (NixOS), the old one stays in place with status `Superseded by v0.2.0` — no hunting through phase folders.

**Naming inside `decisions/`:**

```
decision-<topic-slug>-vN.N.N.md
```

Status line goes at the top of the file body (as in the zero-downtime doc): `

## Status: Accepted`. The filename version tracks the document's own revision history; the status field tracks the decision's lifecycle state.

Want me to restructure the zero-downtime decision to fit this path, or are you happy with where it lives now?

# Working sessions

This repository follows *Process: Running a Claude Code Session*, in uc-processes at `en/docs/processes/running-a-claude-code-session-v0.1.0.md`.

## Session files

All session records live in `en/docs/sessions/`. Timestamps are local time, written `YYYY-MM-DD-HHMM`.

- `<timestamp>-session-prompt.md`: the task prompt, named for when work on it began. If the task arrives as a file somewhere else, move it here. If it arrives in the chat, save it here.
- `<timestamp>-session-report.md`: started once the first findings exist. Update it after every decision and every applied change, without waiting to be asked.
- Audits go in `en/docs/audits/<YYYY-MM-DD>-<audit-title>.md`.

## How changes are made

1. Present findings first, as a table: `| File | Current | Required | Action |`
2. Apply only after explicit confirmation. Never change files silently.
3. Change only what the task or decision covers. Note anything else in the report under "Observations left out of scope", and leave it unchanged.
4. Record each owner decision word for word in the report, then what was applied and how it was checked.
5. Keep a running "Open items" checklist in the report, and say plainly whether the task is complete.

## Conventions

- `README.md` is the source of truth. If it contradicts itself, ask the owner. Don't pick a side.
- Historical files go in an `artifacts/` folder next to them, starting with `> Historical. Superseded by README v<version>.`
- Reports never reproduce secrets. Give `file:line` instead. Example password hashes use the documented `example` placeholder.
- Don't commit or push unless asked.

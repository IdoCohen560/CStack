# Contributing to CStack

CStack is opinionated on purpose — it's one person's Claude Code setup, shared. PRs and issues are
welcome; the bar is "does this make the default setup better for most people, without bloating it."

## Ground rules

- **Keep it curated.** New skills/plugins need a real reason. More is not better — every always-on
  skill costs context tokens. If you add one, say what it replaces or why it earns its keep.
- **Hooks must fail open.** Any hook that can block a session must exit 0 (allow) on every error,
  missing tool, or unexpected input. A broken hook must never trap the user.
- **`setup.sh` stays self-contained and idempotent-ish.** Re-running it should be safe.
- **Credit third parties.** Anything you pull in gets a linked credit in the README.

## Before you open a PR

```bash
bash -n setup.sh uninstall.sh          # syntax
shellcheck setup.sh uninstall.sh        # lint (CI runs this)
```

Test hook changes against the scenarios that matter: chat turn (silent), code turn (gated),
doc-only change (silent), and a bad/empty input (fails open).

## Reporting issues

Include your OS, `node -v`, whether `codex` and `gitnexus` are installed, and the exact command +
output. Redact anything sensitive.

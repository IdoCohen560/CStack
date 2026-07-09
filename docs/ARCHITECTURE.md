# Architecture

CStack is four things layered on a stock Claude Code install: a **reviewer**, a **graph**, a set of
**skills**, and the **hooks** that make the first three run automatically. This doc explains how the
enforcement actually works — the parts that aren't obvious from the README.

## The enforcement loop

```
prompt ──▶ skill-router (route + plan gate) ──▶ you approve the plan ──▶ Claude works ──▶ Stop
                                                                  │
                        ┌─────────────────────────────────────────┤
                        ▼                                          ▼
                 review-guard                               graph-refresh
             (blocks until reviewed)                  (reindex, only if reviewed)
```

Everything hangs off `~/.claude/settings.json` hooks. CStack owns three event types
(`SessionStart`, `Stop`, `UserPromptSubmit`); GitNexus's own hooks own `PreToolUse`/`PostToolUse`.
They don't overlap, so both coexist.

## Files

```
~/.claude/
├── CLAUDE.md                     # operating doctrine (always loaded)
├── settings.json                 # hook wiring
├── hooks/
│   ├── review-sig.sh             # shared lib: signature of code changes + markers
│   ├── review-baseline.sh        # SessionStart: baseline pre-existing changes
│   ├── review-guard.sh           # Stop: block until code is reviewed
│   ├── review-mark.sh            # (manual) record a completed review
│   ├── graph-refresh.sh          # Stop: reindex GitNexus after review
│   └── skill-router.sh           # UserPromptSubmit: nudge relevant skills
└── skills/
    ├── orchestrated-build/       # the full orchestration doctrine (on-demand)
    ├── llm-council/              # multi-model + multi-lens deliberation
    ├── analytics-ui/             # authored: pro data-viz / dashboard design layer
    ├── agent-reach/              # internet access (self-installed by the agent-reach CLI)
    └── threejs-*/                # 10 three.js skills
```

The `agent-reach` CLI itself lives in its own `pipx` venv (`~/.local/bin/agent-reach`), with runtime
state in `~/.agent-reach/`; the Exa web-search MCP is registered at `~/.mcporter/mcporter.json`.

The **analytics-ui** layer is authored (not vendored): the `analytics-ui` skill above encodes the
data-viz design method, and two marketplace plugins supply the machinery — `data@knowledge-work-plugins`
(Anthropic: SQL, analysis, `build-dashboard`, data-visualization) and `ui-ux-pro-max@ui-ux-pro-max-skill`
(design tokens, palettes, chart styles). They compose with `taste-skill`/`impeccable`/`gsap-skills`.

## How "review before done" works

The guard needs to answer one question on every `Stop`: *has the code that changed this session been
reviewed?* It does that with a **content signature**, not a timestamp.

1. **Signature** (`review-sig.sh`) — for every changed **code** file in the repo (docs/config are
   ignored), it hashes the git **blob IDs** of the file at HEAD, in the index, and in the working
   tree. Blob IDs are full-content and format-independent: no truncation, deletions and staged
   changes each produce a distinct signature. The result is one SHA for "the current state of code
   changes."
2. **Baseline** (`review-baseline.sh`, SessionStart) — stamps the signature of whatever was already
   uncommitted when the session began, marking it *acknowledged*. This is why chatting in a repo that
   was already dirty never triggers the guard: only code changed **this session** counts.
3. **Guard** (`review-guard.sh`, Stop) — computes the current signature. If there's no code change,
   or it equals the recorded "reviewed" marker, it exits silently. Otherwise it returns a `block`
   decision telling the agent to run the cross-model review, then `review-mark.sh` to record it.
4. **Mark** (`review-mark.sh`) — after the review, writes the current signature to the marker
   (atomic temp-and-rename). Now the guard sees marker == signature and lets the turn finish.

Every hook **fails open**: missing tools, invalid JSON, non-git dirs, or any error → exit 0 (allow).
A broken hook can annoy, never trap.

## How the graph stays current

`graph-refresh.sh` (Stop) fires alongside the guard but acts only when the code is *already
reviewed* (marker == signature). It runs `gitnexus analyze` in a detached background process (indexing
can take a while; it must not delay your turn), and stamps a separate `claude-graph-marker` on
success so it never re-indexes an unchanged state. A lock (atomic `mkdir`, reclaimed after 30 min)
prevents overlapping index runs.

Net effect: the graph re-indexes exactly once per reviewed change, after the review, in the
background — never on chat, never on unreviewed code.

## How skills auto-activate

Two reinforcing mechanisms, because a static instruction alone isn't reliable:

- **`CLAUDE.md` routing map** — always in context; maps task types to skills ("frontend → taste +
  impeccable", "3D → threejs", etc.) and states that consulting a relevant skill is not optional.
- **`skill-router.sh`** (UserPromptSubmit) — reads each prompt, detects the task type by keyword, and
  injects a short, specific reminder naming the skills to apply. On substantive build/change prompts (but
  not pure questions, and not when you say "just do it") it also injects a **plan-first reminder**: enter
  plan mode and present a plan (approach + skills→parts + delegation + closing review) for your approval
  *before* executing — the opening bookend to the cross-model review's closing gate. This is advisory
  (like the skill hints): it nudges, and **plan mode itself is the actual approval step** — unlike the
  Stop review-guard, this hook does not hard-block. Silent when nothing matches; fails open. The council
  is deliberately *not* keyword-triggered beyond explicit requests — convening it is a judgment call.

## Design decisions worth knowing

- **Different-family review is the core lever.** A model grading its own work re-runs its own blind
  spots; a different family (Codex/GPT) finds what Claude doesn't. This is why the reviewer is
  non-negotiable and why the council fixes its members at Claude + Codex.
- **Diversity by lens, not just by model.** The council multiplies two models into many viewpoints
  (correctness, simplicity, security, performance, UX, cost, red-team) — cheaper and often sharper
  than paying for more model providers.
- **Advisory, not adversarial-hardened.** The markers enforce *your* workflow. They are not a defense
  against a malicious local process, and don't try to be.

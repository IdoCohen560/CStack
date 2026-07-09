#!/usr/bin/env bash
# ============================================================================
#  CStack — the Cohedo Code Stack.  https://github.com/IdoCohen560/CStack
#  One-shot setup that turns a fresh Claude Code into a hardened, skilled,
#  self-reviewing dev environment: Codex cross-model reviewer, GitNexus code
#  graph, curated frontend/coding skills, the llm-council skill, and the hooks
#  that enforce them (review gate, graph refresh, skill router). Wires it all
#  into ~/.claude/settings.json. Idempotent-ish. Auth steps print at the END.
# ============================================================================
set -uo pipefail
say(){ printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills"

printf '\033[1;32m'
cat <<'BANNER'
   ____ ____  _             _
  / ___/ ___|| |_ __ _  ___| | __
 | |   \___ \| __/ _` |/ __| |/ /
 | |___ ___) | || (_| | (__|   <
  \____|____/ \__\__,_|\___|_|\_\
  Cohedo Code Stack — one-command Claude Code power-setup
BANNER
printf '\033[0m'

# --- 0. Prerequisites -------------------------------------------------------
say "Checking prerequisites"
if [ "$(uname)" = "Darwin" ]; then
  have brew || { warn "Install Homebrew first: https://brew.sh"; exit 1; }
  for pkg in node jq gh git ffmpeg; do
    have "$pkg" || { say "brew install $pkg"; brew install "$pkg" || warn "brew install $pkg failed"; }
  done
else
  warn "Non-macOS: ensure node/npm, jq, gh, git, ffmpeg are installed via your package manager."
fi
have node || { warn "node/npm are required — aborting"; exit 1; }
have jq   || { warn "jq is required — aborting"; exit 1; }

# --- 1. Codex CLI (the cross-model reviewer) --------------------------------
say "Installing Codex CLI"
npm install -g @openai/codex || warn "codex install failed (continuing)"

# --- 2. GitNexus (code knowledge graph, native build) -----------------------
say "Installing GitNexus"
npm install -g --allow-scripts=gitnexus,@ladybugdb/core,@scarf/scarf,onnxruntime-node,tree-sitter,tree-sitter-c-sharp,tree-sitter-cpp,tree-sitter-go,tree-sitter-java,tree-sitter-javascript,tree-sitter-php,tree-sitter-python,tree-sitter-ruby,tree-sitter-rust,tree-sitter-typescript,sharp,protobufjs gitnexus \
  || npm install -g gitnexus || warn "gitnexus install failed (continuing)"

# --- 3. Operating-layer files (written byte-exact below) --------------------
say "Writing operating doctrine, skills, and hooks"
mkdir -p "$(dirname "$HOME/.claude/CLAUDE.md")"
cat > "$HOME/.claude/CLAUDE.md" <<'DELIM_CLAUDEMD'
# Operating doctrine

Distilled from the Fable-5 orchestration method, adapted as universal operating discipline.
This is re-read every session — kept short on purpose. Deep/code-specific doctrine lives in
the `orchestrated-build` skill and loads ON DEMAND only.

## Role
- You are the orchestrator: **plan, decide, review, synthesize.** Delegate the legwork.
- Delegate to subagents when a task means reading across many files/sources, or is independent
  work that can run in parallel. Keep the *conclusion*, not the file dumps.
- Delegation isn't free: a small edit you can do by reading ≤1 file, do inline. Don't spawn an
  agent for a one-liner; don't drift into hours of implementation yourself.

## Plan before you execute — the opening gate
The bookend to the cross-model review (the closing gate). For anything beyond a simple chat answer
or a trivial one-liner/lookup, do NOT start editing or building. First **enter plan mode** and
present a short execution plan, then execute only after the user approves it. The plan names:
1. **Approach** — the ordered steps, and what "done" looks like.
2. **Skills → parts** — which skill applies to which part of the work (from the routing map below),
   noting that they COMPOSE (e.g. `analytics-ui` + `data` + `taste-skill` for a dashboard), not pick-one.
3. **Delegation** — what goes to subagents vs stays inline.
4. **Closing review** — the different-family cross-model review that will gate completion.
Keep it tight and scannable (a list, not an essay); present via ExitPlanMode so the user gets an
explicit approve/revise. **Skip the gate** only for: pure chat/Q&A, trivial one-liners/lookups, or
when the user says "just do it" / "go". When unsure whether a task is trivial, plan.

## Cross-model review — MANDATORY closing step on every coding task
This is the default workflow, not an optional extra. NEVER declare code done without it.
1. Orchestrator plans and **hands implementation to subagents** when the work warrants it
   (see delegation above); trivial one-liners stay inline.
2. When the code is written/changed and **before reporting done**, ALWAYS run a **different-family
   adversarial review** to catch what the implementer got wrong — never ship on one model's say-so.
   (Waive ONLY for a truly trivial edit that touches no logic — a typo/rename/copy tweak.)
3. Run `/codex:adversarial-review`, or headless:
   `codex exec --skip-git-repo-check -c model_reasoning_effort="xhigh" "Do not modify files. <prompt>"`
   (Codex/GPT on ChatGPT-Plus auth — bills to OpenAI, not the Claude session.)
4. **Name the CLAIMS the code makes; instruct the reviewer to REFUTE each.** A generic "review this"
   gives a compliment sandwich; "attack claim X — find inputs where it's false" finds real bugs.
   Also hunt: races, unchecked errors, security/verification bypasses, and any mechanism a
   comment/doc promises but the code doesn't implement.
5. **Triage → remediate → re-verify.** Findings are real until disputed with a concrete argument.
   Send fixes back to the implementer; each fix lands with a check that would have caught it.
   Re-review if the remediation was structural.
6. Record the review with `~/.claude/hooks/review-mark.sh` (a Stop-hook **enforces** this — it
   blocks finishing a turn while un-reviewed code changes exist, and stays silent on chat/doc-only
   turns), then report done — stating the review outcome, findings, and what changed.

## Verification & honesty — non-negotiable
- **Never accept self-reported success.** "Tests pass / it works / eval holds" is a starting
  point, not evidence. Re-run it yourself before believing it. A wrong status report is a process
  signal, not just a bug.
- **Verify against the actual files** before asserting how anything behaves. Don't guess.
- **Numbers, not adjectives.** "Recall 58→63 on 30 queries" is a report; "much better now" isn't.
- For every claimed safety mechanism / invariant, demand the **file:line where it's enforced.**
  Docs and comments lie; the lock you're sure exists may never have been written (the phantom lock).
- **Trust the failure *layer*, not the failure *text*** — error messages report the surface the
  error tunneled through, not the root cause.
- Report what you did NOT do, what went wrong, and anything that contradicts the brief — unprompted.

## Reward pushback
- When a subagent (or you) contradicts a brief WITH EVIDENCE — the premise is wrong, the bug is
  elsewhere, the ground truth is fake — that's senior behavior. Act on it, don't override it.
  Punishing push-back trains compliance with wrong briefs.

## Skills-as-memory
- Rules live in **files that get read**, not in chat transcripts. A fix that fails twice isn't a
  hard bug — it's a missing rule. Move it into a skill/doc/comment co-located with what it governs.
- When building or maintaining software, load the **`orchestrated-build`** skill for the full
  pipeline (batch scoping, eval gates, migrations, the review loop, the bootstrap checklist).

## Code understanding — use the graph
- Repos indexed by **GitNexus** (a `.gitnexus/` dir) expose a code knowledge graph via MCP. To
  understand unfamiliar code fast, prefer its graph tools (impact/blast-radius, trace call paths,
  360° symbol context, change detection) over blind grep — see the `gitnexus-*` skills.
- The graph **auto-refreshes after each review** (a Stop hook re-indexes reviewed code changes).
  First-time per repo: run `gitnexus analyze` (add `--embeddings` once for semantic search).

## Proactive skills — activate without being asked
Skills auto-activate by their `description`; the user should NOT have to name them. Before answering,
scan the task and APPLY the relevant skill(s) proactively (a `skill-router` UserPromptSubmit hook also
injects a reminder). Routing map:
- **Any frontend/UI/design work** → `taste-skill` (kill generic slop) + `impeccable` (`/impeccable polish|audit|critique`).
- **Data viz / charts / dashboards / analytics UI / KPIs** → the `analytics-ui` skill, composed WITH
  the `data` plugin (SQL, analysis, `build-dashboard`), `ui-ux-pro-max` + `taste-skill` + `impeccable`
  (surrounding UI), and `gsap-skills` (chart motion). These stack — never pick just one.
- **Animation / scroll / motion** → `gsap-skills`.
- **3D / WebGL / shaders** → `threejs-*` skills.
- **Any coding** → apply the `andrej-karpathy-skills` guidelines (think first, simplest change, surgical).
- **Genuinely contested, high-stakes decision where viewpoints would disagree** → the `llm-council`
  skill. Gate hard: don't convene for single-answer/factual/mechanical questions — offer it instead.
- **Understanding a codebase** → GitNexus graph tools (see above).
- **Reading the internet — any URL, or research/search across social·video·web·code (Twitter/X, Reddit,
  YouTube, GitHub, RSS, LinkedIn, Bilibili, web search, …)** → the `agent-reach` skill. Run
  `agent-reach doctor` to see which backend is live; never hand-roll scraping.
**Skills COMPOSE — they are layers, not a menu you pick one from.** Apply every relevant skill together
and let them stack: e.g. an analytics dashboard = `analytics-ui` (chart rigor) + `data` (the numbers) +
`taste-skill`/`impeccable`/`ui-ux-pro-max` (the surrounding UI) + `gsap-skills` (motion), all at once.
Consulting a relevant skill is not optional; if several apply, run them all. Libraries you'll pull into
projects (not skills): GSAP (`npm i gsap`), react-bits (copy components), 3dsvg, Remotion.

## Context hygiene
- Load context ON DEMAND, never "just to be safe." Filter every command output (`| tail`, `| grep`,
  `| jq`) — raw logs re-bill every turn. Batch related shell calls into one.
DELIM_CLAUDEMD
echo "  wrote $HOME/.claude/CLAUDE.md"

mkdir -p "$(dirname "$HOME/.claude/skills/orchestrated-build/SKILL.md")"
cat > "$HOME/.claude/skills/orchestrated-build/SKILL.md" <<'DELIM_OB'
---
name: orchestrated-build
description: Full doctrine for orchestrating AI agents to build/maintain production software — the operating model, cross-model review pipeline, verification gates, and new-project bootstrap. Load when authoring, reviewing, or shipping code with subagents; not needed for research/analysis work.
---

# Orchestrated build doctrine

Distilled from the Fable-5 method (a fleet of AI agents shipping a production app). The global
`CLAUDE.md` holds the universal principles; this skill holds the code-specific machinery.

## 1. Operating model
- Orchestrator does **planning, architecture, review, merges — nothing else.** Implementation
  happens in subagents. Reasons: context economics, judgment preservation, and independence of
  verification (you can't independently verify code you wrote).
- Exception: trivial edits (≤1 file, no verification beyond a build). If you're reading a third
  file for "a small edit," you mis-scoped it — delegate.
- Backend/architecture work gets a **short written plan first**, approved, then delegated. A
  delegated agent builds *exactly* the prompt — a half-thought design ships fully built.

## 2. The delegation prompt skeleton
Every clean first-pass prompt has these; a mess is missing one:
1. Task in one sentence + the branch (`feature/<slug>` from dev; never commit to main/dev).
2. **Exact absolute file paths** to touch, and files it must NOT touch.
3. The relevant plan section **pasted in** — don't make the agent open a 1000-line doc.
4. Verbatim **build** and **test** commands.
5. **Gates** stated up front (tests green; quality metric holds; pure refactor ⇒ output
   byte-identical).
6. **HARD RULES in caps/bold** — vague preferences get ignored under pressure. (No literals /
   tokens only; model access via protocols never hard-coded names; migrations append-only;
   errors surfaced not swallowed; stay on-branch; no new deps; no TODO standing in for logic.)
7. Skills to read first, naming the **section**.
8. Reporting format: files changed + rationale, test count before→after, metric before→after,
   what it deliberately didn't do, anything that surprised it. "Do NOT claim success on anything
   you did not personally re-run."
9. License to push back: "if the brief's premise is wrong, STOP and report — this is rewarded."

## 3. Cross-model review pipeline (the biggest lever)
```
Model A authors → different-family model adversarially reviews → author remediates → orchestrator
independently verifies + triages disputes → (loop if remediation was major) → merge
```
- Run `/codex:adversarial-review` (Codex/GPT, ChatGPT-Plus auth, bills to OpenAI). "Do not modify
  files" is mandatory in review invocations.
- **Name the diff's claims; instruct the reviewer to attack each.** Also hunt: races, unchecked
  error paths, verification/security bypasses, resource leaks, and **any place a comment/doc
  promises a mechanism the code doesn't implement** (the phantom-lock clause — keep it always).
- Findings assumed real until disputed with a concrete argument. Each fix ships **with a test that
  would have caught it.** Loop the diff back through review if remediation was structural.
- **Role inversion for payment/security-critical code:** the strongest coder authors, a different
  strong family reviews, orchestrator does a final line-level sweep of exactly the flagged regions.

## 4. Verification doctrine
- **Never accept self-reported "tests pass / metric holds."** Before every merge, personally:
  rebuild from merged state, re-run the full test suite, re-run the quality gate, compare numbers
  to the agent's report. One batched, output-filtered shell call. Every time.
- **Quality gate = a hard numeric before/after**, exiting nonzero on regression. Grow the golden
  set BEFORE each capability change (add the failing cases first, watch them fail, then build).
  Pure refactor ⇒ **byte-identical** output, not merely "same".
- Gates run against a **frozen scratch copy** of the data, never a drifting live DB (`.backup`).
- Line-level read only the dangerous categories in a diff (engine math, migrations, concurrency,
  crypto/verification, ranking) — the reviewer covers breadth, you cover depth where subtle
  wrongness survives review.

## 5. Parallelism & resumption
- Two agents parallel **iff their file sets are disjoint.** Two engine-touching batches: sequence
  them. Use worktree isolation for parallel agents.
- Known merge trap: a shared test-registration file — **union both sides**, never pick one (picking
  silently deletes a suite that still compiles). Detect by checking the post-merge test *count*.
- Killed agent with intact transcript: resume by quoting its own last output line + "continue."
  Dead transcript: spawn a fresh fixer with an explicit state dump (verified against the tree).
  Model/effort is fixed at spawn — to change it, stop, harvest state, respawn.

## 6. Security failure mode of AI-built code
The characteristic bug is not insecure idioms — it's **a documented safety mechanism nobody
built.** For every assumed invariant, demand the file:line that enforces it; make authors produce
an "invariant ledger" (invariant → enforcing code → test that fails without it). Audit dimensions
to enumerate: scale, concurrency/lifecycle, resource exhaustion, hostile filesystem input, supply
chain, trust boundaries, time/clock, state-machine holes, user escape hatches.

## 7. Cadences
- Every merge: independent rebuild + tests + gate, numbers in the PR.
- Every big/security diff: cross-model adversarial review, fixes land with pinning tests.
- Every capability batch: golden set grows first, failing.
- ~Every 2 weeks / post-sprint: whole-codebase audit against the dimension list, ranked top-10,
  top slice fixed within 48h, rest boarded. (Cross-batch decay — god objects, duplication, N+1 —
  is invisible per-diff and only shows in a whole-repo read.)
- Duplication retired in dedicated **byte-identical consolidation batches**, not smeared across
  feature diffs.

## 8. New-project bootstrap (day zero)
1. `CLAUDE.md` (<60 lines): product + quality bar; HARD RULES; the gate command + threshold;
   orchestration + routing + review pipeline in one paragraph; "load context ON DEMAND only."
2. Verification harness BEFORE the first feature: golden set / contract tests with a nonzero-exit
   gate; one-line test invocation; frozen scratch data; `scripts/` for anything hand-assembled.
3. Review pipeline: confirm `codex` works; save the adversarial prompt template (claims + phantom-
   mechanism clause); write the role table (default vs payment-inverted vs >400-line mandatory).
4. Skills dir seeded; rule: any fix that fails twice gets encoded into a skill, referenced by
   section name.
5. Memory files: index + project facts + working prefs (incl. **which billing meter is binding**).
6. Board + knowledge store with version-numbered nodes; ingest the plan.

## The ten rules
1. Orchestrator plans/reviews; agents implement; nobody reviews their own code.
2. Never accept self-reported success — rebuild, re-test, re-gate personally, every merge.
3. A different model family attacks every significant diff by its named claims.
4. For every assumed safety mechanism, demand the file:line where it's enforced.
5. Grow the golden set before the change; byte-identical for refactors; frozen data for gates.
6. Reward agents that contradict wrong briefs and refuse fake ground truth.
7. Rules live in files agents must read, co-located with what they govern.
8. Most failures are verification-depth, not reasoning-depth — buy tests/reviews before effort.
9. Route by billing topology; review on the meter that isn't binding.
10. Write handovers as if the next orchestrator is a different model with zero context.
DELIM_OB
echo "  wrote $HOME/.claude/skills/orchestrated-build/SKILL.md"

mkdir -p "$(dirname "$HOME/.claude/skills/llm-council/SKILL.md")"
cat > "$HOME/.claude/skills/llm-council/SKILL.md" <<'DELIM_COUNCIL'
---
name: llm-council
description: Convene a multi-model + multi-lens "council" (independent answers → anonymized peer ranking → chairman synthesis) ONLY when a question genuinely needs more than one viewpoint — high-stakes or hard-to-reverse decisions, or contested trade-offs where reasonable experts would disagree and a single confident answer would be risky. Also on explicit "ask the council" / "/council". Do NOT use for routine, factual, mechanical, or clearly single-answer questions — a normal answer is better and cheaper there.
---

# LLM Council

Convene a council of different-family models to answer a hard question, so the final answer reflects cross-model agreement and catches any single model's blind spots. This is the Fable-5 cross-model principle applied to *answering*, not code review.

## When to use — gate hard, this is expensive
Before convening, pass this self-check — run the council ONLY if BOTH are true:
1. A single confident answer would be genuinely **risky** (high-stakes, hard to reverse, or you're not sure).
2. Independent viewpoints would **plausibly disagree** — there's a real trade-off, not one correct answer.

Convene when: contested architecture/design/strategy calls, "which of these and why", risky irreversible
decisions, judgment calls with real tension — or an explicit "ask the council" / "/council".

Do NOT convene (just answer normally) for: factual/lookup questions, mechanical or well-specified tasks,
anything with one clearly-correct answer, or quick back-and-forth. When unsure whether it's worth it, DON'T —
offer it ("want me to run the council on this?") instead of spending the tokens unprompted.

## Council members (fixed: Claude + Codex)
- **Claude** — you, reasoning natively.
- **Codex / GPT** — via `codex exec --skip-git-repo-check -c model_reasoning_effort="high" "<prompt>"` (ChatGPT-Plus auth; bills to OpenAI).
- **No OpenRouter / extra model providers** — deliberate decision (Ido, 2026-07-07). Two different
  families is enough at the model axis; all further diversity comes from LENSES (below), not more models.

## Viewpoints — diversify by MODEL and by LENS
Two independent axes of diversity. Use both:
- **By model** (different priors): Claude + Codex — fixed. (OpenRouter/extra providers deliberately not
  used; the model axis stays at these two, diversity is carried by lenses.)
- **By lens** (different values): even with only 2 models, assign each Stage-1 answer a distinct lens so the
  council covers more than one concern. Pick the 3–5 lenses that fit the question:
  - **Correctness / rigor** — is it actually true and complete?
  - **Simplicity / maintainability** — the Karpathy lens: least complexity, smallest surface.
  - **Security / safety** — how does this get abused or fail dangerously?
  - **Performance / scale** — what breaks at 10×, cost/latency.
  - **UX / user value** — (product/frontend) does this serve the real user, not the demo?
  - **Cost / pragmatism** — business reality, time-to-ship, maintenance burden.
  - **Red-team / skeptic** — actively argue AGAINST the leading answer; find where it's wrong.
Always include the **red-team/skeptic** lens when the stakes are high — it's the one that catches confident
consensus that's wrong. Map lenses to members (one model can hold several lenses across separate passes).

**Stage 1 — First opinions (independent).** Put the user's question to each member separately; do NOT let them see each other's answers.
- Claude: answer it yourself, fully.
- Codex: `codex exec --skip-git-repo-check -c model_reasoning_effort="high" "<the user's question, verbatim>"`
- Collect each answer. Label them anonymously: Response A, Response B, … (record the label→model map privately; do NOT reveal it during Stage 2).

**Stage 2 — Review & rank (anonymized).** Give EACH member the full anonymized set and this exact prompt (identities hidden so no model plays favorites):
```
You are evaluating different responses to the following question:

Question: {question}

Here are the responses from different models (anonymized):

{responses_text}

Your task:
1. First, evaluate each response individually. For each response, explain what it does well and what it does poorly.
2. Then, at the very end of your response, provide a final ranking.

IMPORTANT: Your final ranking MUST be formatted EXACTLY as follows:
- Start with the line "FINAL RANKING:" (all caps, with colon)
- Then list the responses from best to worst as a numbered list
- Each line should be: number, period, space, then ONLY the response label (e.g., "1. Response A")
- Do not add any other text or explanations in the ranking section

Now provide your evaluation and ranking:
```
- Claude ranks the set; Codex ranks it via `codex exec`. Parse each "FINAL RANKING:" list.

**Stage 3 — Chairman synthesis.** The chairman (default: Claude, the orchestrator) synthesizes using this exact prompt:
```
You are the Chairman of an LLM Council. Multiple AI models have provided responses to a user's question, and then ranked each other's responses.

Original Question: {question}

STAGE 1 - Individual Responses:
{stage1_text}

STAGE 2 - Peer Rankings:
{stage2_text}

Your task as Chairman is to synthesize all of this information into a single, comprehensive, accurate answer to the user's original question. Consider:
- The individual responses and their insights
- The peer rankings and what they reveal about response quality
- Any patterns of agreement or disagreement

Provide a clear, well-reasoned final answer that represents the council's collective wisdom:
```

## What to show the user
1. A short line per member's Stage-1 take (1–2 sentences each), with the model names revealed now.
2. The peer rankings (who ranked what best) and any notable disagreement.
3. The Chairman's final synthesized answer — the headline deliverable.

Keep member raw outputs in scratch, not dumped into the main answer. Report which models participated and flag if any member failed (e.g., Codex errored) so the user knows the council's true size.
DELIM_COUNCIL
echo "  wrote $HOME/.claude/skills/llm-council/SKILL.md"

mkdir -p "$(dirname "$HOME/.claude/skills/analytics-ui/SKILL.md")"
cat > "$HOME/.claude/skills/analytics-ui/SKILL.md" <<'DELIM_ANALYTICS'
---
name: analytics-ui
description: >
  Use PROACTIVELY whenever building or improving any data visualization or analytics UI —
  a chart, graph, plot, dashboard, admin panel, report, KPI / stat tile, sparkline, metric,
  gauge, heatmap, or a table of numbers — in React/Next/web or any frontend, and for any
  "make this data look professional / clean up this dashboard / visualize this data" task.
  Enforces a professional chart stack and design-grade rules for color, chart selection,
  dashboard layout, motion, and accessibility so output reads Stripe/Linear/Vercel-grade,
  not templated. Triggers: chart, graph, plot, dashboard, analytics, data viz, visualization,
  KPI, metric, sparkline, heatmap, gauge, report, admin panel, bar/line/area/pie/scatter/
  donut/bubble chart, "visualize this data", "build a dashboard", "chart this".
metadata:
  origin: CStack — authored, not vendored
---

# Analytics UI — professional data visualization

The bar is **absolutely professional**: a chart or dashboard should look like it shipped from
Stripe, Linear, or Vercel — deliberate, legible, one coherent system — never a library default.
This skill is the **design layer for data**. It composes with, and defers to:

- **`data` plugin** (Anthropic) — the *analytics brain*: SQL, explore-data, chart selection,
  `build-dashboard`, statistical analysis. Use it to decide *what* to show and to wrangle data.
- **`taste-skill` + `impeccable` + `ui-ux-pro-max`** — general premium UI polish. Always apply on
  the surrounding UI.
- **`gsap-skills`** — entrance/scrub motion for charts (see Motion below).
This skill owns the part those don't: **making the numbers themselves look and read professionally.**

## 1. Non-negotiables

1. **No raw library defaults.** Never ship Chart.js/Recharts out-of-the-box styling. Every chart
   gets the project's tokens: type scale, muted gridlines, restrained palette, real number formatting.
2. **Data-ink first.** Delete chrome that doesn't encode data — heavy gridlines, borders, drop
   shadows on bars, 3D, gradients-for-decoration, redundant legends. Maximize signal per pixel.
3. **Label directly, legend last.** Prefer inline/end-of-line labels and value annotations over a
   legend the eye has to ping-pong to. A legend is a fallback, not a default.
4. **Format numbers like a human.** `1.2M` not `1200000`, `+3.4%` not `0.034`, currency/locale aware,
   consistent decimals, thousands separators. Axes get concise ticks, not every value.
5. **Every chart answers one question.** Give it a plain-language title that states the takeaway
   ("Revenue up 18% QoQ"), not the dimension ("Revenue by quarter").
6. **Light AND dark.** Charts are theme-aware from the first line — tokens, not hardcoded hex.

## 2. Stack — pick by need, don't default blindly

| Need | Use | Why |
|---|---|---|
| **80% case** — dashboards, app charts | **shadcn/ui Charts (Recharts) + Tremor blocks** on Tailwind/Radix | React-native, MIT, themeable shell → bespoke look; Recharts is the ecosystem default |
| **Heavy / streaming data** (10k–1M+ pts) | **ECharts** (`echarts-for-react`), or **FINOS Perspective** for real-time grids | canvas/WebGL; SVG (Recharts) drops frames past ~2–5k marks |
| **Fully bespoke / publication-grade** | **visx** (D3 scales + React) → raw **D3** only at the last mile | composable, MIT, total control |
| **Quick exploratory / notebook artifact** | **Observable Plot** or **Vega-Lite** | grammar-of-graphics, minimal code |

**Avoid unless the client mandates + pays:** Highcharts (non-commercial-only free tier), amCharts
(watermark), AG Charts *Enterprise* (AG Charts *Community* is fine, MIT). **Never** TanStack
`react-charts` — archived. Default rule: **Recharts+shadcn → perf wall → ECharts/Perspective →
expressiveness wall → visx → D3.**

## 3. Color — the part that makes it look cheap or expensive

Build a small, intentional system; never let the library assign colors.

- **Categorical:** ONE hue family or a hand-tuned set of ≤6 distinct, equal-weight hues. If you need
  >6 categories, you have a chart-type problem (group "Other", or switch to bar/table). Keep saturation
  and lightness consistent so no series shouts louder than its data warrants.
- **Sequential** (magnitude): single-hue light→dark ramp. **Diverging** (around a midpoint, e.g. +/−):
  two-hue ramp with a neutral center. Never a rainbow — it isn't perceptually uniform and fails a11y.
- **Semantic, fixed:** positive/up = your success token, negative/down = danger token, neutral = muted.
  Never encode good/bad on a red↔green axis alone (colorblind) — pair with sign, arrow, or position.
- **Tokens, light+dark:** `--chart-1..6`, `--chart-grid`, `--chart-axis`, `--chart-label`. Derive
  chart hues from the brand accent; gridlines are the faintest thing on the canvas.
- **Validate:** simulate deuteranopia/protanopia; ensure adjacent categories stay distinguishable and
  every text/mark meets WCAG contrast on both themes. If two series are ambiguous, add pattern/shape,
  don't just tweak hue.

## 4. Chart selection & anti-patterns

- **Comparison across categories →** bar (horizontal if labels are long / many). **Trend over time →**
  line (area only when the cumulative total is the point). **Part-to-whole →** stacked bar or a single
  100% bar; a **pie only** for 2–3 slices, never for ranking. **Correlation →** scatter. **Distribution →**
  histogram/box. **Single number in context →** KPI tile + sparkline. **Dense matrix →** heatmap.
- **Anti-patterns:** pie with >3 slices · donut used as decoration · dual y-axes (misleads — use two
  small-multiples instead) · 3D anything · truncated bar-chart baselines (bars MUST start at 0; lines may
  not) · more than ~4–5 series on one line chart (use small multiples) · a legend where direct labels fit.

## 5. Dashboards — layout & hierarchy

- **Grid:** 12-col responsive; align every card to it; consistent gutters. Cards are quiet containers
  (subtle border OR faint bg, not both; no heavy shadow).
- **Hierarchy = the story, top-left first:** headline KPIs row → primary trend → supporting breakdowns →
  detail tables. Size encodes importance; don't give every widget equal weight.
- **Density with air:** tight, aligned numbers but generous section spacing. Group related metrics; a
  divider or heading beats a box. Consistent card heights per row.
- **States:** design empty / loading (skeletons, not spinners) / error / no-data-for-filter up front.

## 6. Mark specs (the details that signal quality)

- **KPI / stat tile:** label (muted, small caps optional) · big tabular-figures value · delta chip
  (`▲ 3.4%` in semantic color, with the comparison period, e.g. "vs last week") · optional inline
  sparkline. Align values on a baseline across the row.
- **Sparkline:** no axes/ticks; end-dot + end-value; 1px line; color = trend sentiment.
- **Delta:** always signed, always with its basis; color + arrow + text (never color alone).
- **Table of numbers:** right-align numerics, tabular figures, monospace-ish alignment, zebra only if
  dense, sortable headers, sticky header, inline mini-bars/heat for scannability.
- **Tooltip:** show the exact value + label + period; snap to nearest point; never obscure the cursor
  point; dismiss on leave.

## 7. Accessibility (non-optional for "professional")

Titles + `aria-label` describing the takeaway · encode by more than color (shape/pattern/label/position)
· keyboard-focusable series/points where the lib allows (Recharts v3 `accessibilityLayer`) · WCAG-AA
contrast for text/marks on both themes · respect `prefers-reduced-motion` · provide a data-table fallback
for complex charts.

## 8. Motion (via gsap-skills / Framer) — restrained

Animate on first reveal only: bars grow from baseline, lines draw left→right, numbers count up — fast
(≤600ms), eased, staggered subtly. **Never** animate on every re-render or loop idly. Gate all of it on
`prefers-reduced-motion`. Motion clarifies entrance; it is not decoration.

## 9. Pre-flight checklist (run before calling it done)

- [ ] Uses project tokens, works in light **and** dark, zero hardcoded chart hex
- [ ] Palette is intentional (categorical/sequential/diverging chosen correctly) + colorblind-checked
- [ ] Right chart for the question; no anti-pattern (pie>3, dual-axis, 3D, truncated bars)
- [ ] Numbers humanized (units, %, locale, tabular figures); takeaway-first titles
- [ ] Direct labels where possible; gridlines faint; data-ink maximized
- [ ] KPI deltas signed + colored + arrowed (not color alone); tooltips accurate
- [ ] Empty/loading/error states designed; a11y (labels, contrast, non-color encoding, reduced-motion)
- [ ] `taste-skill`/`impeccable` applied to the surrounding UI; stack chosen by §2, not by habit
DELIM_ANALYTICS
echo "  wrote $HOME/.claude/skills/analytics-ui/SKILL.md"

mkdir -p "$(dirname "$HOME/.claude/hooks/review-sig.sh")"
cat > "$HOME/.claude/hooks/review-sig.sh" <<'DELIM_SIG'
#!/usr/bin/env bash
# Shared library for the review-enforcement hooks. Hardened per two adversarial
# reviews (2026-07-07). The signature is derived from git BLOB IDs (full-content,
# formatting-independent, no truncation) for each changed code path — capturing
# HEAD/index/worktree identity so modifications, additions, staged changes and
# deletions all produce distinct signatures.
#
# Accepted by design: the marker is advisory (enforces this session's own
# discipline; it is not a boundary against a hostile same-user process). Dirty
# submodules are not recursed into.

CODE_RE='\.(js|jsx|ts|tsx|mjs|cjs|py|go|rs|java|kt|swift|c|cc|cpp|h|hpp|m|mm|rb|php|cs|scala|sh|bash|zsh|sql|vue|svelte|dart|ex|exs|lua|r|pl|groovy)$'
CODE_BASE_RE='(^|/)(Makefile|Dockerfile|BUILD|Rakefile|Gemfile)$'

# Deterministic, hardened git: no external diff/textconv/pager/color, C locale.
_git() { LC_ALL=C GIT_EXTERNAL_DIFF= GIT_PAGER=cat git -c core.quotePath=false -c diff.external= -c color.ui=false "$@"; }

repo_top() { _git -C "$1" rev-parse --show-toplevel 2>/dev/null; }

# marker_path <repo_top> -> absolute marker path (linked-worktree safe).
marker_path() {
  local top="$1" p
  p=$(_git -C "$top" rev-parse --git-path claude-review-marker 2>/dev/null)
  [ -z "$p" ] && return 1
  case "$p" in /*) printf '%s' "$p" ;; *) printf '%s/%s' "$top" "$p" ;; esac
}

# hook_obj <raw_stdin> -> the single JSON object, or nothing unless input is
# EXACTLY one JSON object (rejects streams like `{...} true`).
hook_obj() { printf '%s' "$1" | jq -c -s 'if (length==1 and (.[0]|type=="object")) then .[0] else empty end' 2>/dev/null; }

# write_marker <top> <sig> : atomic (temp+rename), clobbers a non-regular marker.
write_marker() {
  local top="$1" sig="$2" mp tmp
  mp="$(marker_path "$top")" || return 1
  [ -e "$mp" ] && [ ! -f "$mp" ] && rm -f "$mp" 2>/dev/null
  tmp="${mp}.tmp.$$"
  printf '%s' "$sig" > "$tmp" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  mv -f "$tmp" "$mp" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
}

# read_marker <top> : echo marker content, only if it is a regular (non-symlink) file.
read_marker() {
  local top="$1" mp
  mp="$(marker_path "$top")" || return 1
  [ -f "$mp" ] && [ ! -L "$mp" ] && head -c 200 "$mp" 2>/dev/null
}

_is_code() {
  printf '%s' "$1" | grep -qiE "$CODE_RE" && return 0
  printf '%s' "$1" | grep -qE  "$CODE_BASE_RE"
}

# review_sig <repo_top> -> sha over blob identities of changed code paths; empty if none.
review_sig() {
  local top="$1" base f
  if _git -C "$top" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    base=HEAD
  else
    base=$(_git -C "$top" hash-object -t tree /dev/null 2>/dev/null)   # unborn HEAD -> empty tree
  fi
  [ -z "$base" ] && return 0

  local -a paths=()
  while IFS= read -r -d '' f; do
    [ -n "$f" ] && _is_code "$f" && paths+=("$f")
  done < <(
    { _git -C "$top" ls-files -z --others --exclude-standard      # untracked
      _git -C "$top" diff -z --name-only "$base"                  # unstaged vs base
      _git -C "$top" diff -z --name-only --cached "$base"         # staged vs base
    } 2>/dev/null
  )
  [ ${#paths[@]} -eq 0 ] && return 0

  {
    printf '%s\0' "${paths[@]}" | LC_ALL=C sort -zu | while IFS= read -r -d '' f; do
      hid=$(_git -C "$top" rev-parse -q --verify "$base:$f" 2>/dev/null); [ -z "$hid" ] && hid=none
      iid=$(_git -C "$top" ls-files -s -- "$f" 2>/dev/null | awk 'NR==1{print $2}'); [ -z "$iid" ] && iid=none
      if [ -L "$top/$f" ]; then
        wid="L:$(readlink "$top/$f" 2>/dev/null)"
      elif [ -f "$top/$f" ]; then
        wid=$(_git -C "$top" hash-object --no-filters -- "$top/$f" 2>/dev/null); [ -z "$wid" ] && wid=err
      elif [ -e "$top/$f" ]; then
        wid=special                                               # FIFO/device: don't read (no hang)
      else
        wid=none                                                  # deleted from worktree
      fi
      printf '%s\t%s\t%s\t%s\n' "$f" "$hid" "$iid" "$wid"
    done
  } | shasum | awk '{print $1}'
}
DELIM_SIG
echo "  wrote $HOME/.claude/hooks/review-sig.sh"

mkdir -p "$(dirname "$HOME/.claude/hooks/review-guard.sh")"
cat > "$HOME/.claude/hooks/review-guard.sh" <<'DELIM_GUARD'
#!/usr/bin/env bash
# Stop hook: block ending a turn until CODE changed THIS session has had a
# cross-model review. Silent for chat, non-git dirs, doc/config-only changes,
# and already-reviewed/baselined states. FAILS OPEN on any error or missing tool.
set +e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/review-sig.sh" 2>/dev/null || exit 0

command -v jq  >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

obj="$(hook_obj "$(cat)")"
[ -z "$obj" ] && exit 0                                   # not exactly one JSON object -> fail open

[ "$(printf '%s' "$obj" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0  # no hard loops

cwd="$(printf '%s' "$obj" | jq -r '.cwd // empty')"
[ -z "$cwd" ] && exit 0

top="$(repo_top "$cwd")"
[ -z "$top" ] && exit 0                                   # not a git repo -> chat/other -> allow

sig="$(review_sig "$top")"
[ -z "$sig" ] && exit 0                                   # no code changes -> allow

[ "$(read_marker "$top")" = "$sig" ] && exit 0           # already reviewed or baselined this state

reason="Uncommitted CODE changes in $top have not been through a cross-model review. Per the operating doctrine, before finishing you MUST run a different-family adversarial review: use /codex:adversarial-review, or  codex exec --skip-git-repo-check -c model_reasoning_effort=\"xhigh\" \"Do not modify files. <name the code's claims and tell it to refute each; hunt races, unchecked errors, bypasses, and mechanisms promised but not implemented>\"  . Triage findings, remediate, then run  ~/.claude/hooks/review-mark.sh  to record the review and allow completion. If these changes genuinely need no review (the user explicitly deferred), run  ~/.claude/hooks/review-mark.sh  to acknowledge and proceed."

jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
DELIM_GUARD
echo "  wrote $HOME/.claude/hooks/review-guard.sh"

mkdir -p "$(dirname "$HOME/.claude/hooks/review-mark.sh")"
cat > "$HOME/.claude/hooks/review-mark.sh" <<'DELIM_MARK'
#!/usr/bin/env bash
# Record that the current uncommitted code changes have been cross-model reviewed
# (or acknowledged), so the Stop guard stops blocking. Run as the LAST step of a
# review. Usage: review-mark.sh [dir]  (default: pwd)
set +e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/review-sig.sh" 2>/dev/null || { echo "review-mark: review-sig.sh missing" >&2; exit 1; }

dir="${1:-$(pwd)}"
top="$(repo_top "$dir")"
[ -z "$top" ] && { echo "review-mark: not inside a git repo: $dir" >&2; exit 1; }

sig="$(review_sig "$top")"
if [ -z "$sig" ]; then
  echo "review-mark: no code changes in $top (nothing to mark)"
  exit 0
fi

if write_marker "$top" "$sig"; then
  echo "review-mark: recorded review for $top ($sig)"
else
  echo "review-mark: failed to write marker for $top" >&2
  exit 1
fi
DELIM_MARK
echo "  wrote $HOME/.claude/hooks/review-mark.sh"

mkdir -p "$(dirname "$HOME/.claude/hooks/review-baseline.sh")"
cat > "$HOME/.claude/hooks/review-baseline.sh" <<'DELIM_BASE'
#!/usr/bin/env bash
# SessionStart hook: stamp code changes that ALREADY exist when the session begins
# as acknowledged, so the Stop guard only fires for code changed DURING this session.
# This is what keeps pure-chat turns in an already-dirty repo from ever being blocked.
# Fails open silently.
set +e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/review-sig.sh" 2>/dev/null || exit 0

command -v jq  >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

obj="$(hook_obj "$(cat)")"
[ -z "$obj" ] && exit 0

cwd="$(printf '%s' "$obj" | jq -r '.cwd // empty')"
[ -z "$cwd" ] && exit 0

top="$(repo_top "$cwd")"
[ -z "$top" ] && exit 0

sig="$(review_sig "$top")"
[ -z "$sig" ] && exit 0            # clean repo at start -> nothing to baseline

write_marker "$top" "$sig"
exit 0
DELIM_BASE
echo "  wrote $HOME/.claude/hooks/review-baseline.sh"

mkdir -p "$(dirname "$HOME/.claude/hooks/graph-refresh.sh")"
cat > "$HOME/.claude/hooks/graph-refresh.sh" <<'DELIM_GRAPH'
#!/usr/bin/env bash
# Stop hook (runs alongside review-guard): refresh the GitNexus knowledge graph,
# but ONLY for CODE changes that have already been review-marked. Never fires on
# chat, docs/config, or un-reviewed code. Non-blocking — indexes in the background
# so it never delays finishing a turn. Fails open on any error.
#
# Trigger chain: code changed -> review run -> review-mark.sh writes the review
# marker -> THIS hook sees marker==sig and (re)indexes the reviewed state.
set +e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/review-sig.sh" 2>/dev/null || exit 0

command -v jq  >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

GITNEXUS="/opt/homebrew/bin/gitnexus"
[ -x "$GITNEXUS" ] || GITNEXUS="$(command -v gitnexus 2>/dev/null)"
[ -n "$GITNEXUS" ] || exit 0

obj="$(hook_obj "$(cat)")"
[ -z "$obj" ] && exit 0

cwd="$(printf '%s' "$obj" | jq -r '.cwd // empty')"
[ -z "$cwd" ] && exit 0

top="$(repo_top "$cwd")"
[ -z "$top" ] && exit 0

sig="$(review_sig "$top")"
[ -z "$sig" ] && exit 0                                    # no code changes -> nothing to index

[ "$(read_marker "$top")" = "$sig" ] || exit 0            # not reviewed yet -> skip (review-guard owns this)

# graph marker: skip if this exact reviewed state is already indexed
gmark="$(_git -C "$top" rev-parse --git-path claude-graph-marker 2>/dev/null)"
[ -z "$gmark" ] && exit 0
case "$gmark" in /*) ;; *) gmark="$top/$gmark" ;; esac
[ -f "$gmark" ] && [ ! -L "$gmark" ] && [ "$(head -c 200 "$gmark" 2>/dev/null)" = "$sig" ] && exit 0

# lock (atomic mkdir) to avoid piling up concurrent analyzes; reclaim if stale >30m
lock="$(_git -C "$top" rev-parse --git-path claude-graph-lock 2>/dev/null)"
[ -z "$lock" ] && exit 0
case "$lock" in /*) ;; *) lock="$top/$lock" ;; esac
if ! mkdir "$lock" 2>/dev/null; then
  [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +30 2>/dev/null)" ] || exit 0
  rmdir "$lock" 2>/dev/null && mkdir "$lock" 2>/dev/null || exit 0
fi

# Detached background: incremental index; stamp graph marker on success; release lock.
# Plain `analyze` (no --embeddings) is fast and preserves any embeddings already present.
nohup bash -c '
  "$1" analyze "$2" >/dev/null 2>&1 && printf "%s" "$3" > "$4"
  rmdir "$5" 2>/dev/null
' _ "$GITNEXUS" "$top" "$sig" "$gmark" "$lock" >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
DELIM_GRAPH
echo "  wrote $HOME/.claude/hooks/graph-refresh.sh"

mkdir -p "$(dirname "$HOME/.claude/hooks/skill-router.sh")"
cat > "$HOME/.claude/hooks/skill-router.sh" <<'DELIM_ROUTER'
#!/usr/bin/env bash
# UserPromptSubmit hook: nudge the relevant skills based on the prompt so they
# activate without the user naming them. Injects a short reminder ONLY when the
# prompt matches a task type; silent otherwise. Fails open on any error.
set +e
command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)"
[ -z "$prompt" ] && exit 0
p="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

hints=""
add() { hints="${hints}$1 "; }
m() { printf '%s' "$p" | grep -qE "$1"; }

m 'frontend|front-end|\bui\b|\bux\b|css|tailwind|component|layout|landing|button|responsive|design|\breact\b|\bvue\b|svelte|navbar|modal|dashboard|styling' \
  && add "[design] apply taste-skill (no generic slop) + impeccable (/impeccable polish|audit|critique)."
m 'donut|\bcharts?\b|\bgraphs?\b|\bplot|dashboard|\banalytics?\b|data.?viz|visuali|\bkpis?\b|\bmetrics?\b|sparkline|heatmap|histogram|gauge|\bscatter\b|\bstat tiles?\b' \
  && add "[dataviz] apply analytics-ui + ui-ux-pro-max (+ taste-skill/impeccable for surrounding UI, gsap-skills for restrained chart motion); use the data plugin for SQL/analysis + build-dashboard. Compose them."
m 'animat|\bgsap\b|scroll ?trigger|\bmotion\b|tween|timeline|parallax|transition|easing' \
  && add "[animation] use gsap-skills."
m 'three\.?js|\bwebgl\b|\b3d\b|shader|\bmesh\b|geometry|\bwebgpu\b' \
  && add "[3D] use threejs-* skills."
# Council only on EXPLICIT request — genuine multi-viewpoint need is a judgment call, not a keyword.
m 'ask the council|convene .*(council|panel)|/council|council of (models|llms)|multiple (models|viewpoints|opinions) on' \
  && add "[council] user explicitly wants multi-model deliberation → run the llm-council skill."
m '\bcode\b|implement|refactor|function|bug|build|write (a|the|some)|feature|api|script' \
  && add "[coding] follow the andrej-karpathy guidelines (think first, simplest surgical change)."

# Plan-first: substantive build/change work (but not pure questions or explicit overrides) → nudge a
# plan, presented via plan mode, before executing. Advisory — plan mode is the real approval step.
plan=""
if m 'implement|refactor|\bbuild\b|create|\badd\b|set ?up|write (a|the|some)|feature|migrat|\bfix\b|patch|integrat|\bwire\b|install|configure|scaffold|rewrite|redesign|deploy|make (a|the|me|it|our|us)|improve|revamp|overhaul|change|update|remove|delete|rename|optimi[sz]e|adjust|tweak'; then
  if m '^ *(what|how|why|when|who|which|does|is|are|can|could|would|should|explain|tell me)\b' || m '\?[[:space:]]*$'; then q=1; else q=0; fi
  if m '^ *(just (do it|build|go|ship)|go ahead|go |no plan|without a plan|skip the plan)'; then s=1; else s=0; fi
  [ "$q" = 0 ] && [ "$s" = 0 ] && plan="PLAN FIRST (enter plan mode): before editing or executing, present a short plan — approach + which skills above map to each part (they compose) + what's delegated + the closing cross-model review — and get approval. (Skip for trivial one-liners or pure chat.) "
fi

[ -z "$hints" ] && [ -z "$plan" ] && exit 0
msg="Skill routing (apply BEFORE answering, don't wait to be asked): ${hints}${plan}"
jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$c}}'
exit 0
DELIM_ROUTER
echo "  wrote $HOME/.claude/hooks/skill-router.sh"

# --- 4. Make hooks executable ----------------------------------------------
chmod +x "$CLAUDE_DIR"/hooks/*.sh 2>/dev/null || true

# --- 5. GitNexus -> Claude Code (MCP + gitnexus skills + its own hooks) -----
say "Wiring GitNexus into Claude Code"
have gitnexus && gitnexus setup -c claude || warn "gitnexus setup skipped"

# --- 6. Skill plugins (marketplace add + install) ---------------------------
say "Installing skill plugins"
add_install(){ # $1=owner/repo  $2=plugin@marketplace
  claude plugin marketplace add "$1" >/dev/null 2>&1 || warn "marketplace add $1 failed"
  claude plugin install "$2" >/dev/null 2>&1 && echo "  installed $2" || warn "install $2 failed"
}
add_install openai/codex-plugin-cc            codex@openai-codex
add_install Leonxlnx/taste-skill              taste-skill@taste-skill
add_install pbakaus/impeccable                impeccable@impeccable
add_install greensock/gsap-skills             gsap-skills@gsap-skills
add_install vercel-labs/agent-browser         agent-browser@agent-browser
add_install jordanrendric/claude-video-vision claude-video-vision@claude-video-vision
add_install multica-ai/andrej-karpathy-skills andrej-karpathy-skills@karpathy-skills
add_install nextlevelbuilder/ui-ux-pro-max-skill ui-ux-pro-max@ui-ux-pro-max-skill
add_install anthropics/knowledge-work-plugins    data@knowledge-work-plugins
# HELD (agent security/governance; installs its own session hooks). Uncomment to add:
# add_install microsoft/agent-governance-toolkit agt-governance@agent-governance-toolkit

# --- 7. three.js skills (no plugin manifest -> copy skills in) --------------
say "Installing three.js skills"
TJ="$(mktemp -d)"
if git clone --depth 1 https://github.com/CloudAI-X/threejs-skills.git "$TJ" >/dev/null 2>&1; then
  for d in "$TJ"/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    n="$(basename "$d")"; rm -rf "$CLAUDE_DIR/skills/$n"; cp -R "$d" "$CLAUDE_DIR/skills/$n" && echo "  + $n"
  done
else warn "three.js skills clone failed"; fi
rm -rf "$TJ"

# --- 8. Agent Reach (internet access: 15 platforms, multi-backend routing) --
say "Installing Agent Reach (web/social/video/dev reach for your agent)"
# CLI lives in its own venv via pipx (not on PyPI -> install from source).
# `agent-reach skill --install` copies the skill into ~/.claude/skills itself.
if [ "$(uname)" = "Darwin" ]; then have pipx || { say "brew install pipx"; brew install pipx || warn "brew install pipx failed"; }; fi
export PATH="$HOME/.local/bin:$PATH"   # pipx installs land here; make them visible to this run so `have` is accurate + re-runs skip
if have pipx; then
  if have agent-reach; then echo "  agent-reach already installed ($(agent-reach version 2>/dev/null))"
  else pipx install "git+https://github.com/Panniantong/Agent-Reach.git" >/dev/null 2>&1 && echo "  installed agent-reach" || warn "agent-reach install failed (continuing)"; fi
  have agent-reach && { agent-reach skill --install >/dev/null 2>&1 && echo "  + skills/agent-reach" || warn "agent-reach skill install skipped"; }
else warn "pipx unavailable — skipping Agent Reach CLI"; fi
# Free zero-config unlocks: YouTube (yt-dlp) + web semantic search (Exa via mcporter, no API key).
have yt-dlp || { [ "$(uname)" = "Darwin" ] && { say "brew install yt-dlp"; brew install yt-dlp || warn "brew install yt-dlp failed"; }; }
npm install -g mcporter >/dev/null 2>&1 && echo "  installed mcporter" || warn "mcporter install failed (continuing)"
# Register the free Exa MCP at the SYSTEM config path so it resolves from any working directory.
MCP="$HOME/.mcporter/mcporter.json"; mkdir -p "$HOME/.mcporter"; [ -f "$MCP" ] || echo '{}' > "$MCP"
MTMP="$(mktemp "$MCP.XXXXXX")"   # temp in the SAME dir as target so the mv below is atomic
if jq '.mcpServers = (.mcpServers // {}) | .mcpServers.exa = {baseUrl:"https://mcp.exa.ai/mcp"}' "$MCP" > "$MTMP" 2>/dev/null; then
  mv "$MTMP" "$MCP"; echo "  + Exa MCP (free web search)"
else warn "Exa MCP config merge failed"; rm -f "$MTMP"; fi

# --- 9. Register custom hooks in settings.json (preserves gitnexus Pre/Post) -
say "Registering custom hooks in settings.json"
SETTINGS="$CLAUDE_DIR/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
TMP="$(mktemp)"
if jq --arg h "$HOME" '
    .hooks = (.hooks // {})
    | .hooks.SessionStart   = [ {hooks:[{type:"command",command:($h+"/.claude/hooks/review-baseline.sh")}]} ]
    | .hooks.Stop           = [ {hooks:[{type:"command",command:($h+"/.claude/hooks/review-guard.sh")}]},
                                {hooks:[{type:"command",command:($h+"/.claude/hooks/graph-refresh.sh")}]} ]
    | .hooks.UserPromptSubmit = [ {hooks:[{type:"command",command:($h+"/.claude/hooks/skill-router.sh")}]} ]
  ' "$SETTINGS" > "$TMP" 2>/dev/null; then mv "$TMP" "$SETTINGS"; echo "  hooks registered"; else warn "settings merge failed"; rm -f "$TMP"; fi

# --- 10. Make it yours — one-time prompt to use YOUR GitHub identity --------
# CStack is authored by IdoCohen560; your commits should be under your OWN identity.
# We prompt at most ONCE: a marker file records that it's been handled, so re-running
# setup.sh never asks again (delete the marker to redo). We never silently overwrite a
# valid non-Ido identity, and we only write git config if you opt in.
say "Make it yours (git identity)"
IDMARK="$CLAUDE_DIR/.cstack-identity-set"
if [ -f "$IDMARK" ]; then
  echo "  already handled — skipping (remove $IDMARK to redo)"
else
  gname="$(git config --global user.name 2>/dev/null || true)"
  gmail="$(git config --global user.email 2>/dev/null || true)"
  # Detect the CStack AUTHOR's identity by UNIQUE signals only (email / GitHub handle), never by a
  # common name like "Ido Cohen" — that would false-match a different real person of the same name
  # (nagging them, or clobbering their valid identity). Compare case-insensitively.
  is_ido=0
  [ "$(printf '%s' "$gmail" | tr 'A-Z' 'a-z')" = "ido.the.cohen@gmail.com" ] && is_ido=1
  [ "$(printf '%s' "$gname" | tr 'A-Z' 'a-z')" = "idocohen560" ] && is_ido=1
  if [ -n "$gname" ] && [ -n "$gmail" ] && [ "$is_ido" = 0 ]; then
    echo "  using your existing git identity: $gname <$gmail> — left as-is"
    : > "$IDMARK"
  elif { exec 3<>/dev/tty; } 2>/dev/null; then   # actually open the terminal, not just stat it
    { printf '  CStack was built by IdoCohen560 — commits you make should be under YOUR identity.\n'
      [ "$is_ido" = 1 ] && printf '  (your git config currently reads as that author; replace it below)\n'
      printf '  Your git name  (blank to skip): '; } >&3
    IFS= read -r newname <&3 || newname=""
    if [ -n "$newname" ]; then
      printf '  Your git email (blank to skip): ' >&3
      IFS= read -r newmail <&3 || newmail=""
      git config --global user.name "$newname" && echo "  set user.name  = $newname"
      [ -n "$newmail" ] && git config --global user.email "$newmail" && echo "  set user.email = $newmail"
    else
      echo "  skipped — set later:  git config --global user.name 'You'; git config --global user.email 'you@example.com'"
    fi
    exec 3>&-
    : > "$IDMARK"   # prompted once — don't ask again
  else
    warn "no terminal to prompt — set YOUR git identity so commits aren't misattributed:"
    echo "    git config --global user.name  'Your Name'"
    echo "    git config --global user.email 'you@example.com'"
    # marker intentionally NOT written: a later interactive run still gets the one prompt
  fi
fi

# --- 11. Remaining MANUAL steps --------------------------------------------
say "DONE. Remaining MANUAL steps:"
cat <<'MANUAL'
  0. Make it YOURS: CStack is IdoCohen560's — use your own GitHub. Setup prompts once for your
     git identity (name/email); re-run after `rm ~/.claude/.cstack-identity-set` to redo. If you
     cloned this repo, point `origin` at your own fork before publishing your own version.
  1. GitHub auth (org/private repos):        gh auth login
  2. Codex reviewer auth (ChatGPT Plus):     codex login      -> "Sign in with ChatGPT"
  3. Restart Claude Code so CLAUDE.md, skills, plugins, and hooks load.
  4. Per code repo, build its graph once:    cd <repo> && gitnexus analyze --embeddings
  5. (Optional) claude-video-vision needs ffmpeg (installed) + a vision API key to run.
  6. Agent Reach: run  agent-reach doctor  to see live channels (7/15 work with zero config).
     Unlock login-gated platforms on demand — tell your agent "help me set up Twitter" (or
     Reddit / Facebook / Instagram / XiaoHongShu / LinkedIn / Xueqiu).

  Deliberately NOT installed (context for future you):
   - OpenMythos           : from-scratch model-training code, not usable tooling.
   - notebooklm           : removed by choice.
   - agent-governance-toolkit : security/governance; marketplace added by hand only.
   - GSAP / react-bits / 3dsvg / Remotion : LIBRARIES used inside projects (npm i / copy
                            components), NOT Claude skills.
   - llm-council (web app): reimplemented as the local llm-council SKILL (Claude + Codex + lenses).
MANUAL

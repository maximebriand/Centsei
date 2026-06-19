# Design — Centsei

## Problem

Teams capped on Copilot AI credits (e.g. 3900 credits/user/month on Enterprise).
The framework's single goal: **do the same work while consuming fewer credits**,
without degrading deliverable quality.

## Why a multi-agent orchestrator (and not one big prompt)

Under **token-based** billing (since 01/06/2026), the cost of a session =
`Σ(token_volume × model_rate)` per agent. Two levers follow from this:

1. **Model arbitrage**: push the bulk volume (exploration, reading) toward a
   floor-rate/token model, reserve premium for the small, high-value volume.
2. **Volume reduction**: don't make the model pay for what a deterministic tool
   does for free, and don't carry raw content between agents.

A single mono-model prompt allows neither: everything goes at the same rate,
everything pollutes the same context.

## Feasibility (verified, June 2026)

Copilot natively supports sub-agents:
- definition via a `.github/agents/<name>.agent.md` file;
- `model` frontmatter — **a single model name (string)**. The Copilot CLI rejects a
  YAML list/prioritized-fallback, so each agent pins exactly one model;
- the **`bash`** tool → shell execution (ripgrep, git, fd, jq) — hence the deterministic layer;
- isolated context per sub-agent, parallel execution, agent-initiated delegation.

Observed limits (and how we work around them):
- **No `effort`/`reasoning` field** → passed as an instruction in the prompt.
- **No native structured contract**: a sub-agent's output is re-injected as
  free text → we impose the format via instruction + caveman hand-offs (files).
- **No declarative context control** → each agent only pulls what it needs
  via its tools (it isn't handed a big pushed context).

> Chosen target surface: **Copilot CLI / SDK** (not VS Code custom agents), because
> `bash` is native there — the deterministic layer and caveman hand-offs don't depend
> on any MCP server to write or maintain.

## Architecture

```
                ┌───────────────┐
   user ───────▶│    centsei    │  cheap model, never reads code
                │  (route only) │  decides: agent × model × effort × context
                └──────┬────────┘
        ┌──────────────┼───────────────┬─────────────┐
        ▼              ▼               ▼             ▼
   ┌─────────┐   ┌───────────┐   ┌───────────┐ ┌──────────┐
   │explorer │   │spec-planner│  │implementer│ │ reviewer │
   │  nano   │   │  sonnet   │   │  sonnet   │ │  nano    │
   │ rg/fd   │   │  (SDD)    │   │  edit     │ │ git diff │
   └────┬────┘   └─────┬─────┘   └─────┬─────┘ └────┬─────┘
        │  compact contracts (≤500 tk) │            │
        └──────────────┴────────────── caveman ─────┘
                 (JSON files / git diff, zero tokens)

   + debugger (nano→sonnet, triage from trace/log)
   + test-author (sonnet, regression tests with mandatory edge cases)
```

The full core roster is **explorer, spec-planner, implementer, reviewer,
vibe-coder, debugger, test-author** (+ centsei the router = 8 slots).
The `explorer` is **dual-mode**: `locate` (default, compact findings) and
`explain` (read-only "How does X work?" Q&A, grounded in sources it greps first).
Off the routing table by default: the opt-in add-ons `scribe` (human docs /
Outline) and `refactorer` (planned).

### Architecture principle: "deterministic first"

> If a CLI command can answer the question, the model is not called.

| Work | Tool | The model never does this |
|---|---|---|
| Text / regex search | ripgrep | grep |
| Structural search (AST) | ast-grep | parse the AST |
| Locate files | fd / find | list a directory |
| Transform JSON/text | jq / sed / awk | reformat |
| Repo state | git diff / log | describe a diff |

Typical gain: locating a symbol via `rg` ≈ 15 tokens, versus ~1,500 tokens if you
have a model read 5 files (**≈ 100×** on the localization phase).

Residual trap: the tool output is still input tokens → we **filter it before**
injecting it (`--max-count`, `-C 0`, `--max-columns`, byte cap per agent).

### Compact contract & caveman

See `CONTRACT.md`. Rule: no raw content between agents, cap ≤ 500 tokens
per intermediate agent. Critical hand-offs (diff to reviewer, pre-filter
before implementer) go through shell scripts + files — zero model call.

## Generic vs parameterized

**Provided by the framework (do not touch):** the core `.agent.md` files
(explorer, spec-planner, implementer, reviewer, vibe-coder, debugger,
test-author) plus the opt-in add-ons (scribe, refactorer), the caveman scripts,
the contract format, the routing and effort rules.

### Roster size & routing degradation

A cheap router degrades once it has to discriminate between too many routing
classes — recall and precision both drop past roughly **6–8** of them. So the
default routing table keeps **≤ 8 core slots** (centsei + 7 targets). Add-ons
(`scribe`, `refactorer`) deliberately stay **off** the routing table until a
team enables them in `agents.config.yml` — they exist as files but don't widen
the router's decision space by default.

**Edited by each team (a single file):** `.github/agents.config.yml` — stack,
budget, alert threshold, model whitelist, allowed tools, output caps.

## Safeguards (cost anti-regression)

1. **A scout that says too much** → enforced output cap (bytes) per agent.
2. **Centsei over-delegating** → rule "< 3 agents for a task < 30 min".
3. **Context that bloats** (iterative SDD specs) → summarize the specs, don't reload.
4. **A scout that guesses** → the explorer emits a `confidence` score (low/med/high)
   on its findings; low confidence flags ambiguity for Centsei to weigh.
5. **Silent scope creep** → the reviewer rejects a diff that touches files beyond
   the plan's scope by more than ~20% (`scope_violation: true`).
6. **Cutting the highest-leverage corner** → spec-planner stays on Sonnet; the
   plan is where a cheap-model mistake costs the most downstream.

## Points to verify depending on the Copilot CLI version

- the exact tool names in `tools:` (`bash`? `shell`?);
- the invocation / delegation syntax between agents;
- the exact model identifiers (map the `models.md` labels onto the real IDs);
- the availability of `ast-grep` on the runners if structural search is used.

## Decision history

- **Surface = CLI/SDK** (not VS Code): native `bash` > MCP dependency.
- **Centsei on a cheap model**: it routes, it doesn't reason heavily, small volume.
- **Caveman = enforcement** of the contract, not a mere bonus: the runtime does not
  guarantee a structured hand-off, so we materialize it through files + scripts.

# Copilot models & routing rules

Pricing grid (June 2026, **token-based**, per million tokens). Inline
completions free. **Cached = 10% of the input rate.** 1 credit = $0.01.

> ⚠️ Rates and the model lineup change regularly. Check the official
> GitHub page "Models and pricing for GitHub Copilot" before locking in a budget.

| Tier | Model | Input | Output |
|---|---|---|---|
| 💚 Budget | GPT-5.4 nano | $0.20 | $1.25 |
| 💚 | GPT-5 mini / Raptor mini | $0.25 | $2.00 |
| 💚 | Gemini 3 Flash | $0.50 | $3.00 |
| 💚 | GPT-5.4 mini | $0.75 | $4.50 |
| 💚 | Claude Haiku 4.5 | $1.00 | $5.00 |
| 🟡 Mid | Gemini 3.1 Pro | $2.00 | $12.00 |
| 🟡 | GPT-5.4 | $2.50 | $15.00 |
| 🟡 | Claude Sonnet 4.6 | $3.00 | $15.00 |
| 🔴 Premium | GPT-5.3-Codex | $1.75 | $14.00 |
| 🔴 | Claude Opus 4.8 | $5.00 | $25.00 |
| 🔴 | GPT-5.5 | $5.00 | $30.00 |

## The 3 routing dimensions

**1. Model ∝ deliverable value**
- Disposable output (mapping, intermediate summary) → **nano / mini**
- Output delivered to the user (code, spec, review) → **mid** minimum
- Critical output with heavy reasoning (architecture, blocking security) → **premium**, exceptional

**2. Effort ∝ ambiguity (not size)**
- `low`: well-defined, repetitive task
- `medium`: a few choices to make
- `high`: ambiguous, trade-offs, obscure debugging

> Effort **is not a native field** of Copilot agents: it is passed as an explicit
> instruction in the sub-task handed off by Centsei.

**3. Context — the 3-level rule**
- *Minimal* (always): task description + expected output contract
- *Scoped* (if relevant): target files, domain spec, conventions
- *Explicitly excluded*: everything else (pure cost)

## Reference routing table

| Task type | Agent(s) | Model | Effort | Context |
|---|---|---|---|---|
| Exploration / audit | explorer | nano | low | targeted paths |
| Spec writing (SDD) | spec-planner | sonnet | medium | explorer summary + ticket |
| Planned implementation | implementer | sonnet | medium–high | validated plan |
| Isolated bug fix | implementer | gpt-5.4-mini | low | file(s) + trace |
| Prototype / vibe | vibe-coder | gpt-5.4-mini | low | free description |
| PR / diff review | reviewer | nano | low | diff + plan |
| Large refactoring | explorer → spec-planner → implementer | nano → sonnet → sonnet | high | architecture snapshot |
| Debugging from a trace / CI log | debugger | nano → sonnet | low→high | log + failing test |
| Test writing / extension | test-author | sonnet | medium | change + existing tests |
| "How does X work?" / codebase Q&A | explorer (explain mode) | nano | low | targeted paths |

## The trap never to forget

A cheap agent's output **becomes the input** of the next agent. If the nano
explorer returns a 2,000-token dump to the Sonnet implementer, those 2,000 tokens are
billed at **Sonnet's input rate**. Model arbitrage only holds if
the interface between agents stays compact (see `CONTRACT.md`).

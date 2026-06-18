# Compact I/O contract between agents

The keystone of token savings. The Copilot runtime **does not enforce** a
schema: a sub-agent's output is re-injected as free text into the parent agent.
Without discipline, tokens explode. This contract is therefore enforced by
two means:

1. **Strict instruction** in each agent's system prompt (caps below).
2. **Caveman hand-offs**: for critical hand-offs, the contract is written to
   disk (`.github/scripts/*.sh`) and the next agent re-reads it via `bash`,
   rather than having it transit through a model.

## Golden rule

> An intermediate agent **never** returns raw file content.
> Cap: `summary` ≤ 120 words, output ≤ ~500 tokens. Beyond that → `"truncated": true`.
> Only the final agent (the one delivering to the user) is uncapped.

## Base schema (common)

```json
{
  "agent": "<name>",
  "status": "ok | error | needs_human | ...",
  "summary": "≤ 120 words, facts, no prose.",
  "next_agent": "implementer | reviewer | spec-planner | human | null"
}
```

Each agent adds its specific fields (`findings`, `tasks`, `changed_files`,
`issues`, `tech_debt`…). See the `# Output` block of each `.agent.md`.

## Why it matters (reminder)

Copilot billing since 01/06/2026 = **per token** (input + output + cached,
at the model's API rate; 1 credit = $0.01; cached = 10% of input;
inline completions free). A cheap sub-agent that returns a raw dump turns
its output tokens into **expensive input tokens** at the next premium
agent: the entire benefit of model arbitrage is wiped out. The compact contract
prevents exactly that.

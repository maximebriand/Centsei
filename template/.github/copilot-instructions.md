# Copilot Instructions — repository tooled by Centsei

> This repository uses **Centsei**: a *credit-frugal* multi-agent orchestration.
> These global rules are loaded by Copilot for every interaction. The
> team-specific config lives in `.github/agents.config.yml`.

## Guiding principle: save AI credits

Copilot billing is **per token** (input + output + cached). Before any
action, minimize tokens — in this order:

1. **Tools before tokens.** If a deterministic command answers the question
   (`ripgrep`, `fd`, `git`, `jq`), use it. Never make a model read or reason
   for what a tool does for free (search, list, filter, transform).
2. **The right model for the task.** Exploration / reading → *cheap* model.
   Code generation → *mid* model. Premium reserved for review. Stay within the
   `allowed_models` whitelist in `agents.config.yml`.
3. **Compact contracts.** Between agents, exchange only bounded summaries
   (≤ 500 tokens) — never raw file contents (see `docs/CONTRACT.md`).
4. **Scoped context.** Inject only the strict minimum; explicitly exclude the rest.

## Workflow

- Go through the **Centsei** agent: `/agent centsei`. It routes to
  `explorer`, `spec-planner`, `implementer`, `reviewer`, `vibe-coder`,
  `debugger` or `test-author`. Codebase Q&A ("How does X work?") goes to
  `explorer` in its **explain** mode (read-only). `scribe` (human docs / Outline)
  is an opt-in add-on, off the routing table until enabled in `agents.config.yml`.
- Two modes: **SDD** (spec first) or **vibe** (quick proto) — see
  `defaults.workflow` in `agents.config.yml`.
- Chain as few agents as possible: **< 3 agents** for a task estimated < 30 min.

## Conventions

- Follow the team's conventions file (`stack.conventions_file`).
- No initiative outside the assigned scope.
- Mark any technical debt introduced with an explicit `TODO`.

Architecture details: see the Centsei README and `docs/design.md`.

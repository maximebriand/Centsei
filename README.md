# Centsei 🥋

> **Master the art of credits.** A cheap model explores, a strong model decides.

A **generic, stack-agnostic** multi-agent orchestration framework for
**GitHub Copilot CLI**, with a single goal: **saving AI credits**.

Since 01/06/2026, Copilot bills **per token** (input + output + cached, at
each model's API rate). The cost-saving lever is no longer "how many requests"
but **"what volume of tokens, on which model"**. This framework exploits that:

- **The right model for each task** — exploration on a *nano* model at a very low
  rate/token, generation on a *mid* model, premium reserved for critique.
- **Tools before tokens** — everything a deterministic command can do (search,
  filter, transform) is **never** paid for in model tokens. `ripgrep`, `fd`,
  `git`, `jq` do the heavy lifting; the model only sees compact results.
- **Compact contracts + "caveman" hand-offs** — agents exchange bounded summaries
  (≤ 500 tokens), never file dumps. Critical hand-offs go through shell scripts +
  files, with no model call.

> Designed to be **given to any team, any stack**:
> you only edit a single config file.

## Installation

```bash
# In the target repo
/path/to/centsei/install.sh

# Or targeting a specific repo
/path/to/centsei/install.sh /path/to/my-repo

# Preview without writing anything
/path/to/centsei/install.sh --dry-run /path/to/my-repo
```

The installer copies `template/.github/` (agents, scripts, `centsei-instructions.md`) into
the target repo and makes the scripts executable. It is **non-destructive & update-safe**:
it never overwrites your `copilot-instructions.md` (only adds a one-time reference) nor your
`agents.config.yml` (created once, preserved on every re-run); the Centsei-owned files are
refreshed.

**Prerequisites on the machine / runner:** `ripgrep` (rg), `fd`, `jq`, `git`.
Optional: `ast-grep` (sg) for structural search.

## After installation

1. Edit `.github/agents.config.yml` → your stack, your budget, the model whitelist.
2. Launch Copilot CLI in the repo, then `/agent centsei`.
3. Centsei routes, delegates, aggregates — you only interact with it.

## Updating

Centsei lives in its own repo, so updating is two steps:

```bash
cd /path/to/centsei && git pull                   # get the latest framework
/path/to/centsei/install.sh /path/to/your-repo    # redeploy (update-safe)
```

Re-running the installer **refreshes** the Centsei-owned files (agents, scripts,
`centsei-instructions.md`) and **preserves** your `agents.config.yml` and your
`copilot-instructions.md`. If an update adds new config options, the installer points you
to the template so you can diff and copy what you want.

## The roster

| Agent | Role | Default model | Why |
|---|---|---|---|
| `centsei` | Routes, delegates, aggregates. Never reads code. | `gpt-5-mini` | judgment, small volume |
| `explorer` | Locates (ripgrep/fd), returns a compact contract. Also answers "How does X work?" (explain mode, read-only) | `gpt-5.4-nano` | high read volume → floor rate |
| `implementer` | Writes the code of the validated plan | `claude-sonnet-4.6` | generation quality |
| `reviewer` | Re-reads the diff, points out deviations | `gpt-5.4-nano` | heavy input / light output |
| `spec-planner` | Writes spec + plan (SDD / OpenSpec flow) | `claude-sonnet-4.6` | structured reasoning |
| `vibe-coder` | Quick prototype without a spec | `gpt-5.4-mini` | speed, contained budget |
| `debugger` | Triages from a trace/log, hands a repro to implementer | `gpt-5.4-nano` → escalates to sonnet | mechanical triage at floor rate, escalate only when unclear |
| `test-author` | Writes regression tests, edge cases mandatory | `claude-sonnet-4.6` | test quality gates the pipeline |

Two supported workflows: **SDD** (spec-planner → implementer → reviewer) and
**vibe coding** (vibe-coder directly).

## Opt-in add-ons

These agents exist as files but stay **off the default routing table** until you
enable them in `.github/agents.config.yml` (`addons:`):

- `scribe` — doc-writer for human-facing docs (README, changelog, ADR), with
  optional publishing to a wiki (Outline) via an **optional** MCP server; falls
  back to local files when the MCP is absent.
- `refactorer` — planned add-on for large-scale transforms (not yet built).

## Structure

```
centsei/
├── README.md
├── LICENSE                     # MIT
├── install.sh                  # installer
├── VERSION
├── template/                   # what gets deployed into a repo
│   └── .github/
│       ├── centsei-instructions.md   # Centsei rules (referenced from copilot-instructions.md)
│       ├── agents/*.agent.md         # the core agents (+ opt-in add-ons)
│       ├── agents.config.yml         # the ONLY file each team edits
│       └── scripts/*.sh              # caveman hand-offs
└── docs/
    ├── design.md               # detailed architecture + decisions
    ├── models.md               # Copilot pricing grid + routing rules
    └── CONTRACT.md             # the compact I/O contract between agents
```

## How it saves credits (summary)

1. **Model arbitrage**: the volume (exploration) goes at the floor rate; premium
   only touches the small, high-value volume.
2. **Deterministic first**: `ripgrep` locates a symbol for ~15 tokens where
   having a model read the files would cost ~1,500 (≈ 100×).
3. **Compact contracts**: no dumps between agents → you don't re-pay at premium
   input rates for what a cheap agent produced.
4. **Caveman**: critical hand-offs (diff, pre-filter) happen in shell, zero tokens.

## End-to-end example

Task: *"Add a validation: email is required at signup."*
You only talk to Centsei; it routes the rest.

```text
$ copilot
> /agent centsei
> Add a validation: email is required at signup.
```

**1. Centsei** (cheap model) — classifies the task as `implement`, but it must
first locate. It delegates to `explorer` at effort `low`. It reads no file.

**2. Explorer** (nano) — opens nothing "just to look", it runs ripgrep:

```bash
rg -l --max-count 1 -i 'signup|register|inscription' src/ libs/
rg --json --max-count 5 -C 0 -i 'email' src/auth/signup.form.ts \
  | jq -c 'select(.type=="match") | {file:.data.path.text, line:.data.line_number}'
```

It returns a **compact contract** (≈ 15 tokens of localization, not ~1,500 of reading):

```json
{ "agent": "explorer", "status": "ok",
  "summary": "Signup in src/auth/signup.form.ts ; email field without required validation.",
  "findings": [{ "file": "src/auth/signup.form.ts", "lines": "22-30", "topic": "email not required", "severity": "info" }],
  "next_agent": "implementer" }
```

**3. Centsei → Implementer** (mid, e.g. Sonnet) — receives *only* this contract
(not the raw code) + the plan. It opens the single targeted file, adds the validation,
returns:

```json
{ "agent": "implementer", "status": "ok",
  "summary": "Validation 'email required' added to signup.form.ts + test.",
  "changed_files": ["src/auth/signup.form.ts"], "tests_added": ["src/auth/signup.form.spec.ts"],
  "review_target": "HEAD", "next_agent": "reviewer" }
```

**4. Caveman hand-off** (zero tokens) — a script prepares the diff for the reviewer:

```bash
.github/scripts/handoff-impl-to-reviewer.sh src/auth
# → {"status":"ready","patch":"/tmp/review_target.patch","lines":18}
```

**5. Reviewer** (nano) — reads the diff itself (`git diff HEAD`), does not receive the
exploration context. Returns `approved` or targeted deviations.

**6. Centsei** — short synthesis to the user.

> **Credit outcome**: the bulk of the volume (localization, re-reading) ran on
> *nano* models; only the implementer — small volume, high value — used a
> *mid* model. No raw file content transited between agents.

## Compatibility — to check against your Copilot CLI version

Copilot agent capabilities evolve fast. Before a wide rollout, confirm on
your version:

- the exact field and tool names in the `.agent.md` frontmatter (`tools: [bash, …]`);
- that the shell execution tool is indeed called `bash` (otherwise adapt the `.agent.md`);
- the invocation/delegation syntax between agents (`/agent`, `/delegate`);
- the exact identifier of each model (the names here derive from the pricing
  grid labels — map them onto the real IDs exposed by your plan).

See `docs/design.md` for the detail of decisions and points to verify.

## License

[MIT](LICENSE) © 2026 Maxime Briand.

# molagent — Steering Content Guide

This document explains how molagent's steering content (rules, knowledge,
lessons, subagents) integrates with pi's native discovery mechanism.

---

## How pi discovers AGENTS.md

Pi (`core/resource-loader.js`) loads context files from exactly two places:

1. The **global agent directory** (`~/.pi/agent/` by default): a single
   `AGENTS.md` or `CLAUDE.md` found there is always loaded.
2. The **ancestor walk**: every directory from cwd up to `/`, each checked
   for an `AGENTS.md` / `CLAUDE.md` file directly in it.

Pi does **not** scan installed packages, the `.pi/` subdirectory, or arbitrary
filenames. To make pi load `steering/AGENTS.md` from this package you must
put it somewhere on one of those two paths.

Disable discovery entirely with `pi --no-context-files`.

### Option A — Symlink at project root (recommended for shared HPC projects)

```bash
# From your project directory:
ln -s <pkg-root>/steering/AGENTS.md ./AGENTS.md
```

Pi will find it on next startup via the ancestor walk.

### Option B — Symlink into the global agent directory (recommended for personal use)

```bash
mkdir -p ~/.pi/agent
ln -s <pkg-root>/steering/AGENTS.md ~/.pi/agent/AGENTS.md
```

Applies to every pi session regardless of cwd.

### Option C — Copy the content into your existing AGENTS.md

If you already have a project `AGENTS.md`, append the molagent content (or
`cat <pkg-root>/steering/AGENTS.md >> ./AGENTS.md`). Symlinks are preferred
so updates from `pi update` propagate automatically.

> **Note.** A top-level `AGENTS.md` symlink ships inside the package for
> reference, but it is **not** auto-discovered by pi; installation does not
> place anything in your project or home directory.

---

## AGENTS.md content

`steering/AGENTS.md` contains:

- **RULE #0** — login-node compute guard (also enforced by the extension hook)
- **RULE #1** — no software installs without explicit permission
- **RULE #2** — no refactoring of working scripts
- **House rules** — LAMMPS verbatim copy, file overwrite protocol, etc.
- **Analysis Discipline** — status-before-numbers, no reference without verification
- **Team Protocol** — when and how to use Critic / Verifier subagents
- **Context7 rule** — when to call the MCP docs tool
- **Memory hygiene** — one fact, one home; no project state in global files
- **Pointers to knowledge and lesson files** — slash commands to load them

---

## Knowledge files (on-demand loading)

Heavy reference documents live under `steering/knowledge/`. Load them when
the task needs that context — not on every session (cost: each file is 100–280 lines).

| Slash command | File loaded | When to use |
|---------------|-------------|-------------|
| `/hpc` | `steering/knowledge/hpc.md` | SLURM job submission, partitions, `va`/`job-limits` |
| `/lammps` | `steering/knowledge/lammps.md` | LAMMPS input files, OPLS-AA defaults, crash recovery |
| `/gaussian` | `steering/knowledge/gaussian.md` | g16 module, `%nprocshared`, `GAUSS_SCRDIR`, ω tuning |
| `/molagent-rules` | `steering/AGENTS.md` | Re-inject full rule set mid-session |

---

## Lesson files (past-incident library)

Lessons are the war stories behind the rules. Load them when you hit a related
error or want full context for a RULE.

| Command | File | Content |
|---------|------|---------|
| `/incident-log installs-and-login` | `steering/lessons/installs-and-login.md` | Incidents behind RULE #0 and #1; SLURM introspection template |
| `/incident-log lammps-gotchas` | `steering/lessons/lammps-gotchas.md` | LAMMPS / Colvars / PLUMED debugging incidents |
| `/incident-log verify-discipline` | `steering/lessons/verify-discipline.md` | Analysis Discipline operational tactics |
| `/incident-log plot-discipline` | `steering/lessons/plot-discipline.md` | Figure conventions, audience-friendly polymer names, parity checklist |

---

## Subagent definitions

Four subagent role definitions live under `agents/`. Pi does **not** spawn
them as separate processes — they are markdown protocols that the `/critic`
and `/verify` prompt templates instruct the LLM to read and follow in the
current session:

| Definition | File | Invoked by |
|------------|------|------------|
| `critic` | `agents/critic.md` | `/critic <plan-or-claim>` (`prompts/critic.md`) |
| `verifier` | `agents/verifier.md` | `/verify <claim> <data-paths>` (`prompts/verify.md`) |
| `explorer` | `agents/explorer.md` | Reference only; cited from steering and prompts |
| `planner` | `agents/planner.md` | Reference only; cited from steering and prompts |

Full protocol for when and how to use each subagent:
`steering/knowledge/team_protocol.md`. Both `prompts/critic.md` and
`prompts/verify.md` tell the LLM to `read` the corresponding `agents/*.md`
file first so the protocol is in scope before the agent acts.

---

## Extension role in steering

The TypeScript extension complements pi's native steering:

1. **`before_agent_start` hook** — injects a short (~40-token) session header
   listing ready skills, runner mode, and available slash commands. The LLM
   needs this to know which slash commands exist.

2. **`tool_call` hook (RULE #0)** — the ONLY piece of steering that pi cannot
   do declaratively. Enforces the login-node compute guard:
   - `strict` — hard block: the bash command is rejected
   - `warn` (default) — confirm prompt: user can allow through
   - `off` — guard disabled

3. **`/molagent:doctor`** — reports which AGENTS.md files pi discovered, which
   prompt templates are registered, and which subagents are available. Use
   this to debug "why isn't the LLM following RULE #X?".

---

## User profile via `MOLAGENT_PROFILE`

Set `MOLAGENT_PROFILE=<key>` in your shell and the extension will read
`examples/about.<key>.md` at `session_start` and **append it to the system
prompt** in `before_agent_start` (delimited by `--- User profile ---`
markers). Pi will not auto-discover `.pi/about.md` — the extension does the
injection itself.

```bash
export MOLAGENT_PROFILE=uarizona-puma   # loads examples/about.uarizona-puma.md
```

Drop your own profile in `<pkg-root>/examples/about.<your-key>.md` if you want
to define a new one. If `MOLAGENT_PROFILE` points at a file that does not
exist, the extension emits a yellow warning at session start.

---

## What the extension does NOT do

- Does **not** rewrite or replace the AGENTS.md system prompt content — pi
  handles AGENTS.md / CLAUDE.md discovery on its own.
- Does **not** auto-load knowledge files (cost: each is 100–280 lines; loading
  all four every session would blow out context for short tasks).
- Does **not** ship `claude_config/about.md` content — user identity is the
  user's choice; see `steering/about.example.md` and `examples/about.*.md`.
- Does **not** auto-migrate the user's `~/.pi/agent/AGENTS.md`. The shipped
  `steering/AGENTS.md` is discovered only after you symlink/copy it into one
  of the two pi-recognised locations above; merging with any existing global
  AGENTS.md is a manual step.

---

## Migration from Claude Code (share_molagent)

If you were using `share_molagent` with Claude Code, see `docs/MIGRATION.md`.
The steering content has moved:

| Old location | New location |
|--------------|--------------|
| `~/.claude/CLAUDE.md` | `steering/AGENTS.md` (auto-discovered by pi) |
| `~/.claude/knowledge/*.md` | `steering/knowledge/*.md` + `/hpc` `/lammps` `/gaussian` slash commands |
| `~/.claude/lessons/*.md` | `steering/lessons/*.md` + `/incident-log <slug>` |
| `~/.claude/about.md` | `steering/about.example.md` (template) |
| Claude Code subagents | `agents/critic.md`, `agents/verifier.md`, etc. |

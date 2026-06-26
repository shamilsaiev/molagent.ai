# molagent — Migration from Claude Code (share_molagent)

This document is for users coming from the original `share_molagent` repository
used with Claude Code on UArizona Puma.

---

## What changed

| Aspect | Old (share_molagent + Claude Code) | New (pi-molagent + pi) |
|--------|-------------------------------------|------------------------|
| Install | Manual copy to `~/.claude/skills/` | `pi install git:<repo>` |
| Config | Hardcoded paths in scripts | Single `molagent.json` |
| Rules | `~/.claude/CLAUDE.md` (not enforced) | `steering/AGENTS.md` + RULE #0 extension hook |
| Knowledge | `~/.claude/knowledge/*.md` | `steering/knowledge/*.md` + `/hpc /lammps /gaussian` |
| Lessons | `~/.claude/lessons/*.md` | `steering/lessons/*.md` + `/incident-log` |
| Subagents | Claude Code `general-purpose` subagent | `agents/critic.md` + `agents/verifier.md` |
| RULE #0 | Advisory text only | Enforced by `tool_call` hook (warn by default) |

---

## Migration steps

### 1. Install pi

```bash
npm install -g @earendil-works/pi-coding-agent
```

### 2. Install molagent

```bash
pi install git:github.com/avatsaev/pi-molagent
# or via SSH:
pi install git:git@github.com:avatsaev/pi-molagent
# or project-local (from a local checkout):
pi install -l ./pi-molagent
```

### 3. Create molagent.json

```bash
# Inside pi:
/molagent:init
```

Then edit `.pi/molagent.json` to fill in your paths.  
For UArizona Puma, start from:

```bash
cp <pkg>/examples/molagent.uarizona-puma.json ~/.pi/agent/molagent.json
```

Fill in the `ligpargen.*` and `binaries.vmd` keys with your actual paths.

### 4. Set up your user profile (optional)

```bash
# Use the preserved Puma profile (extension reads it at session_start and
# appends it to the system prompt):
export MOLAGENT_PROFILE=uarizona-puma
```

To define your own, drop `examples/about.<your-key>.md` into the package and
use the same env var. Pi does **not** auto-load `.pi/about.md`; see
`docs/INSTALL.md` for the two supported workflows.

### 5. Verify

```
/molagent:doctor
```

Check that skills you use are "ready" and paths are resolved correctly.

---

## Hardcoded path changes in scripts

Phase 2 of the molagent migration (see `PI_EXTENSION_PREP_PLAN.md` §10)
updates the skill scripts to read from `$MOLAGENT_EFFECTIVE_CONFIG` instead
of hardcoded paths. Until that is complete, you can still run the scripts
directly by setting env vars manually:

```bash
export MOLAGENT_PKG_ROOT=/path/to/pi-molagent
export MOLAGENT_EFFECTIVE_CONFIG=/path/to/your/molagent.json
```

---

## Steering content

Your old `~/.claude/CLAUDE.md` content is preserved verbatim (with only
path rewrites) in `steering/AGENTS.md`. Pi discovers it via parent-walk.

Your old knowledge and lesson files are in `steering/knowledge/` and
`steering/lessons/`. Load them with `/hpc`, `/lammps`, `/gaussian`, or
`/incident-log <slug>`.

**Do not delete your old `~/.claude/CLAUDE.md` until you verify that
`steering/AGENTS.md` is being discovered correctly** (`/molagent:doctor`
will show its path).

---

## RULE #0 enforcement change

In Claude Code, RULE #0 was advisory text. In pi-molagent, it is enforced
by a `tool_call` hook. Default policy is `warn` (confirm prompt before
allowing heavy Python on the login node).

To restore the old advisory-only behavior:

```json
// molagent.json
{
  "cluster": {
    "login_node_compute_policy": "off"
  }
}
```

To upgrade to hard enforcement:

```json
{
  "cluster": {
    "login_node_compute_policy": "strict"
  }
}
```

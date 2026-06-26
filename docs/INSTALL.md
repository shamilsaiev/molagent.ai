# molagent — Installation Guide

## Prerequisites

molagent is a pi coding agent package. You need pi installed first:

```bash
npm install -g @earendil-works/pi-coding-agent
```

## Install molagent

### One-liner (recommended)

```bash
curl -fsSL https://molagent.ai/install.sh | bash
```

What it does:

1. Verifies Node.js ≥ 18 and npm are on PATH (does **not** auto-install Node).
2. Installs the pi coding agent globally via npm (skipped if already present).
3. Installs the molagent ecosystem of pi extensions, skipping any already
   registered with `pi list`:
   - `npm:pi-web-access`
   - `npm:@juicesharp/rpiv-ask-user-question`
   - `npm:pi-powerline-footer`
   - `git:github.com/avatsaev/pi-molagent` (with SSH fallback)

Safe to re-run; every step is idempotent. No sudo. No PATH edits.

**Private repo note.** Until `avatsaev/pi-molagent` is made public, `git clone`
needs GitHub authentication on the install machine. The script tries HTTPS
first and falls back to SSH if HTTPS clone fails. You need at least one of:

- An HTTPS git credential helper (`gh auth login`, or a `~/.git-credentials`
  entry, or a `GITHUB_TOKEN` consumed by your helper), OR
- A GitHub SSH key on this machine — verify with `ssh -T git@github.com`.

Environment-variable knobs (export before piping into bash):

| Variable | Default | Meaning |
|----------|---------|---------|
| `MOLAGENT_AUTH` | `auto` | `auto` → HTTPS then SSH. Force one with `https` or `ssh`. |
| `MOLAGENT_REF` | — | git ref / tag / commit to pin pi-molagent to. |
| `MOLAGENT_LOCAL` | — | Set to `1` to install into `./.pi/` instead of `~/.pi/`. |

Example — force SSH and pin to a tag, project-local:

```bash
curl -fsSL https://molagent.ai/install.sh \
  | MOLAGENT_AUTH=ssh MOLAGENT_REF=v0.1.0 MOLAGENT_LOCAL=1 bash
```

If you'd rather see the script before running it:

```bash
curl -fsSL https://molagent.ai/install.sh -o install.sh
less install.sh
bash install.sh
```

### Manual install — from GitHub

Canonical repository: <https://github.com/avatsaev/pi-molagent>

```bash
# HTTPS (no SSH key required) — recommended
pi install git:github.com/avatsaev/pi-molagent

# SSH (if you have a GitHub SSH key configured)
pi install git:git@github.com:avatsaev/pi-molagent

# Pin to a tag or commit
pi install git:github.com/avatsaev/pi-molagent@v0.1.0
```

### Project-local install (recommended for shared HPC projects)

```bash
pi install -l git:github.com/avatsaev/pi-molagent
```

This writes to `.pi/settings.json` in the current directory.  
Teammates who run pi from the same directory will automatically get the package.

### Local path install (development / testing)

```bash
pi install /path/to/pi-molagent
# or from the parent directory:
pi install ./pi-molagent
```

---

## Configure molagent

After install, create your `molagent.json`:

```bash
/molagent:init
```

This runs in pi and writes a starter config to `.pi/molagent.json` with
auto-discovered binary paths. Edit the file to fill in cluster-specific paths.

### Config file location

molagent searches for config in this order (first found wins):

1. `$MOLAGENT_CONFIG` (env var — absolute path)
2. `.molagent.json` or `molagent.json` in the current directory
3. `.pi/molagent.json` in the current directory
4. `~/.pi/agent/molagent.json` (global user config)

### UArizona Puma (ssaiev / jlbredas group)

Copy the preserved working config and fill in the absolute paths:

```bash
cp <pkg>/examples/molagent.uarizona-puma.json ~/.pi/agent/molagent.json
# Edit and fill in:
#   ligpargen.container, ligpargen.boss_dir, ligpargen.src_dir,
#   ligpargen.conda_python, ligpargen.conda_profile,
#   binaries.vmd, binaries.lammps_fallback
```

### Local desktop (no SLURM)

```bash
cp <pkg>/examples/molagent.local-desktop.json .pi/molagent.json
# Edit binaries.lammps to your lmp binary path
```

---

## Verify installation

Inside pi, run:

```
/molagent:doctor
```

This prints a status table of all configured tools and skill readiness.

---

## External dependencies

molagent does **not** ship external scientific binaries. Install them separately
and point molagent at them via `molagent.json`.

### VMD 1.9.4+ with TopoTools

Required by: `opls-pipeline`  
Download: https://www.ks.uiuc.edu/Research/vmd/  
Config key: `binaries.vmd`

### LigParGen 2.1 + BOSS 5.1

Required by: `ligpargen-from-mol`, `opls-pipeline`  
LigParGen: https://github.com/leelasd/ligpargen  
BOSS: https://zarbi.chem.yale.edu/software.html (license required)

Two install routes are supported. Both are first-class; pick whichever fits
your environment.

#### Route A — Apptainer container (typical HPC use)

Most HPC sites ship LigParGen + BOSS as a single `.sif` image with a
bind-mounted BOSS source tree and a patched LigParGen checkout.

Config:

```json
"ligpargen": {
  "container":     "/shared/sw/boss_runtime.sif",
  "boss_dir":      "/shared/sw/boss",
  "src_dir":       "/shared/sw/ligpargen",
  "conda_python":  "/shared/sw/miniconda3/envs/ligpargen/bin/python",
  "conda_profile": "/shared/sw/miniconda3/etc/profile.d/conda.sh"
}
```

Requires `binaries.apptainer` (defaults to `apptainer` on PATH).

#### Route B — Native install (workstation OR cluster `$HOME`)

No container required. Works on a personal Linux machine, in `$HOME` on a
cluster login node, or anywhere else you can run conda.

1. **Install Miniconda** (or Mambaforge) and create the env:

   ```bash
   conda create -n ligpargen python=3.10 rdkit openbabel numpy
   conda activate ligpargen
   ```

2. **Install BOSS 5.1** under any path you control (e.g. `$HOME/opt/boss`).
   Follow the BOSS README; ensure `$BOSSdir` is set inside the env activation
   script if BOSS needs it at runtime.

3. **Clone the patched LigParGen tree** (e.g. to `$HOME/opt/ligpargen`).

4. **Point `molagent.json` at the native install**, leaving `container` empty:

   ```json
   "ligpargen": {
     "container":     "",
     "boss_dir":      "/home/me/opt/boss",
     "src_dir":       "/home/me/opt/ligpargen",
     "conda_python":  "/home/me/miniconda3/envs/ligpargen/bin/python",
     "conda_profile": "/home/me/miniconda3/etc/profile.d/conda.sh",
     "conda_env":     "ligpargen"
   }
   ```

5. **Verify** with `/molagent:doctor`. The doctor reports container vs. native
   route and confirms each path exists.

Workstation users typically pair this with `runner.mode = "local"` (see
`docs/CONFIG.md` §`runner`) so SLURM is not required.

Config keys (both routes): `ligpargen.container`, `ligpargen.boss_dir`,
`ligpargen.src_dir`, `ligpargen.conda_python`, `ligpargen.conda_profile`.

### LAMMPS

Required by: `solvent-pack`, `dihedral-fit-pipeline`, `opls-pipeline`  
Either a SLURM module (`binaries.lammps_module`) or a binary (`binaries.lammps`).  
UArizona Puma: `module load lammps/7Feb2024`

### Gaussian g16

Required by: `dft-charges`, `dihedral-fit-pipeline`  
Config keys: `binaries.gaussian`  
UArizona Puma: `module load gaussian/g16_C.02`

### SLURM

Required when `runner.mode = "slurm"` (the default).  
No config needed — molagent calls `sbatch` from PATH.  
Set `runner.mode = "local"` on a desktop without SLURM.

### Context7 (optional)

Context7 is a separate MCP server for fetching up-to-date library documentation.
molagent does **not** bundle it. To install:

```bash
pi install npm:@upstash/context7-mcp
```

Once installed, the standing rule in `steering/AGENTS.md` about when to call
Context7 applies automatically. No molagent-side configuration needed.

---

## User profile (optional)

To give the agent context about who you are, you have two options.

**Option A — env var (recommended).** Set `MOLAGENT_PROFILE=<key>` and the
extension will read `examples/about.<key>.md` from the package and append it
to the system prompt on every session:

```bash
export MOLAGENT_PROFILE=uarizona-puma     # loads examples/about.uarizona-puma.md
# Add to ~/.bashrc to persist
```

To define your own profile, drop a markdown file into the package at
`<pkg>/examples/about.<your-key>.md` and use the same env var.

**Option B — add the content to your AGENTS.md.** Copy the template into your
project- or global-level AGENTS.md (see `docs/STEERING.md` for the two
discovery paths):

```bash
cat <pkg>/steering/about.example.md >> ~/.pi/agent/AGENTS.md   # global
# or
cat <pkg>/examples/about.uarizona-puma.md >> ./AGENTS.md       # project-local
```

> Pi does **not** auto-load files under `.pi/about.md` or any non-`AGENTS.md`
> filename. Use one of the two options above.

See `docs/STEERING.md` for the complete steering integration story.

# molagent — Configuration Reference

All configuration lives in a single `molagent.json` file.
Run `/molagent:init` inside pi to generate a starter file with auto-discovered paths.  
Run `/molagent:doctor` to validate the current configuration.

## File locations (search order)

| Priority | Path |
|----------|------|
| 1 | `$MOLAGENT_CONFIG` (env var, absolute path) |
| 2 | `<cwd>/.molagent.json` |
| 3 | `<cwd>/molagent.json` |
| 4 | `<cwd>/.pi/molagent.json` |
| 5 | `~/.pi/agent/molagent.json` |

First found wins. All missing keys fall back to built-in defaults.

---

## Schema

### `binaries`

Paths to external executables. Omit any key to fall back to PATH lookup.

| Key | Default | Required for |
|-----|---------|--------------|
| `vmd` | PATH lookup | `opls-pipeline` (topology, VMD convert steps) |
| `lammps` | `lmp_mpi` | `solvent-pack`, `dihedral-fit-pipeline`, `opls-pipeline` |
| `lammps_module` | `lammps/7Feb2024` | SLURM `module load` statement in job scripts |
| `lammps_fallback` | — | Fallback binary when module load fails |
| `gaussian` | `g16` | `dft-charges`, `dihedral-fit-pipeline` |
| `apptainer` | `apptainer` | `ligpargen-from-mol`, `opls-pipeline` |
| `python` | `python3` | Rendered into SLURM scripts |

### `ligpargen`

LigParGen + BOSS configuration.  
Required by: `ligpargen-from-mol`, `opls-pipeline`.

Two install routes are first-class — the `container` key selects between them:

- **Apptainer container** (HPC sites): set `container` to the `.sif` image and
  `boss_dir` / `src_dir` to the host directories that get bind-mounted in.
- **Native conda env** (cluster `$HOME` or local workstation): leave
  `container` empty (`""`) or omit it. molagent then uses `conda_python`
  directly with `boss_dir` / `src_dir` pointing at the native install tree.

Paths may be anywhere on disk — cluster scratch, `$HOME`, or `/opt` on a
laptop. `docs/INSTALL.md` §LigParGen documents both routes end-to-end.

| Key | Default | Description |
|-----|---------|-------------|
| `container` | — | Apptainer `.sif` image path. **Leave empty for the native (no-apptainer) flow.** |
| `boss_dir` | — | BOSS install directory. Container route: host bind-mount target. Native route: install root on the local filesystem. |
| `src_dir` | — | Patched LigParGen source tree. Same dual role as `boss_dir`. |
| `conda_python` | — | Absolute path to conda env Python binary. Required when `container` is empty; used as the in-container interpreter when `container` is set. |
| `conda_profile` | — | `conda.sh` profile path (sourced before activation in the native flow). |
| `conda_env` | `ligpargen` | Conda environment name |
| `charge_model` | `CM1A-LBCC` | LigParGen `-cgen` flag |
| `default_formats` | `["lammps"]` | Output formats |

### `runner`

Controls how SLURM jobs are submitted or whether they run locally.

| Key | Default | Values |
|-----|---------|--------|
| `mode` | `slurm` | `"slurm"` \| `"local"` \| `"dry-run"` |

#### `runner.slurm`

| Key | Default | Description |
|-----|---------|-------------|
| `account` | — | SLURM account (`#SBATCH --account`) |
| `default_partition` | `high_priority` | Primary partition |
| `qos` | — | QOS string (omit to use cluster default) |
| `fallback_partitions` | `["standard","windfall"]` | In order; used by skill docs |
| `submitter` | `sbatch` | sbatch binary or wrapper script |
| `max_walltime_h` | `240` | Hard cap used in validation |
| `request_walltime_h` | `220` | Walltime written into job scripts |

#### `runner.local`

| Key | Default | Description |
|-----|---------|-------------|
| `ntasks` | `min(os.cpus(), 8)` | CPU cores for `mpirun -np`. `/molagent:init` writes the auto-detected value; capped at 8 to avoid pinning every workstation core. Set explicitly to override. |
| `mpirun` | `mpirun` | MPI launcher binary |

### `cluster`

Cluster identity and RULE #0 enforcement policy.

| Key | Default | Description |
|-----|---------|-------------|
| `name` | `unknown` | Free-form label shown in status bar |
| `login_node_compute_policy` | `warn` | `"strict"` (hard block) \| `"warn"` (confirm) \| `"off"` |
| `login_node_python_stdlib_only` | `true` | Informational; used in doctor report |
| `scratch_dir` | `/tmp/$SLURM_JOB_ID` | `GAUSS_SCRDIR` and temporary directories |
| `module_load_cmd` | `module load` | Rendered into job scripts |

### `lammps_defaults`

OPLS-AA force-field defaults written verbatim into generated LAMMPS input files.

| Key | Default |
|-----|---------|
| `pair_style` | `lj/cut/coul/long 12.0` |
| `pair_modify` | `mix geometric tail yes` |
| `kspace_style` | `pppm 1.0e-4` |
| `bond_style` | `harmonic` |
| `angle_style` | `harmonic` |
| `improper_style` | `harmonic` |
| `dihedral_style` | `nharmonic` |
| `special_bonds` | `lj/coul 0.0 0.0 0.5` |

### `skills`

Skill-specific knobs. All optional; built-in defaults are listed.

#### `skills.solvent_pack`

| Key | Default |
|-----|---------|
| `default_min_dist` | `2.0` Å |
| `default_dispersion_k` | `2` |
| `bond_warn_threshold` | `2.5` Å |

#### `skills.merge_data`

| Key | Default |
|-----|---------|
| `default_overlap_cutoff` | `3.0` Å |

#### `skills.dihedral_fit_pipeline`

| Key | Default |
|-----|---------|
| `default_partition` | `high_priority` |
| `outlier_mad_factor` | `5.0` |
| `outlier_min_kcal` | `1.0` kcal/mol |

#### `skills.dft_charges`

| Key | Default |
|-----|---------|
| `method` | `M06-2X` |
| `basis` | `6-31G**` |
| `pop` | `Hirshfeld` |

---

## Environment variables (set by the extension)

These are written at `session_start` and consumed by skill scripts.
Do not set them manually in normal use.

| Variable | Value |
|----------|-------|
| `MOLAGENT_EFFECTIVE_CONFIG` | Path to the merged config JSON tempfile |
| `MOLAGENT_PKG_ROOT` | Absolute path to the package root |
| `MOLAGENT_PROFILE` | *(user-set)* Profile key for `examples/about.<key>.md` |
| `MOLAGENT_CONFIG` | *(user-set)* Override config file path |

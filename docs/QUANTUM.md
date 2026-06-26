# molagent — Quantum (Gaussian) Skill Catalogue

Reference for the **14 `gaussian-*` skills** bundled with molagent. These skills
cover the full lifecycle of a Gaussian DFT / TDDFT calculation as
**file-building** and **file-parsing** tools — they do **not** execute Gaussian
themselves. The user runs `g16` separately (typically via SLURM; see
[`steering/knowledge/gaussian.md`](https://github.com/avatsaev/pi-molagent/blob/main/steering/knowledge/gaussian.md) for the
canonical template).

> The Gaussian skillset is fully independent from the OPLS-AA / LAMMPS skills
> (`opls-pipeline`, `dihedral-fit-pipeline`, …). No shared code, no shared
> config, no shared lib helpers.

---

## At a glance

```
                ┌───────────────────────────────────────────────────────────────┐
                │ Step 1                                                        │
                │   gaussian-structure-check  ──── validate SMILES / xyz / pdb  │
                └─────────────────────────────┬─────────────────────────────────┘
                                              ↓ (structure + charge/mult)
                ┌─────────────────────────────────────────────────────────────────┐
                │ Step 2 — input builders (write .gjf, do not run g16)            │
                │                                                                 │
                │   gaussian-input-builder  (generic .gjf writer + DB validation) │
                │     ↑                                                           │
                │     │ used by ↓                                                 │
                │   gaussian-sp           Single-point                            │
                │   gaussian-freq         Frequency + thermochemistry             │
                │   gaussian-fix-imag     Repair imaginary modes (iterative)      │
                │   gaussian-tuned-omega  ω-tuning for range-separated DFT        │
                │   gaussian-tddft        Excited states (TDDFT / TDA)            │
                │   gaussian-deltae       ΔE / binding / counterpoise             │
                │   gaussian-scan         PES scans (6 modes)                     │
                └─────────────────────────────┬───────────────────────────────────┘
                                              ↓ (one or many .gjf files)
                                          ┌───────┐
                                          │ USER  │ runs g16 (SLURM)
                                          └───┬───┘
                                              ↓ (.log / .out files)
                ┌─────────────────────────────────────────────────────────────────┐
                │ Step 4 — output analyzers (read .log/.out, do not run g16)      │
                │                                                                 │
                │   gaussian-parse-output      Generic parser (status, E, geo, …) │
                │   gaussian-ir-raman          IR/Raman + scaling factors         │
                │   gaussian-tddft-analysis    UV-vis + MO contributions          │
                │   gaussian-deltae-analysis   Assemble final binding / ΔE        │
                │   gaussian-scan-analysis     Energy vs scan coord + min/TS      │
                └─────────────────────────────────────────────────────────────────┘
```

---

## Skill catalogue

| Skill | Step | One-line purpose | Inputs | Outputs | Pairs with |
|---|---|---|---|---|---|
| `gaussian-structure-check` | 1 | Validate structure, connectivity, fragments, charge/multiplicity | SMILES, xyz, pdb, mol, mol2, sdf, gjf/com/gau/inp, generic text-coord | summary table; details on demand | runs before everything in step 2 |
| `gaussian-input-builder` | 2 | Generic `.gjf` writer; validates functional / basis / solvent / dispersion against local DBs | structure file + method/basis/solvent flags | one `.gjf` | called by every 2-x skill |
| `gaussian-sp` | 2-0 | Single-point energy | structure | one `.gjf` (no `Opt`, no `Freq`) | `gaussian-parse-output` |
| `gaussian-freq` | 2-1 | Frequency / thermochemistry (optionally combined with `Opt`) | structure | one `.gjf` (`Freq` or `Opt Freq`) | `gaussian-fix-imag`, `gaussian-ir-raman` |
| `gaussian-fix-imag` | 2-2 | Repair imaginary modes by displacing along normal coords | prior `.log` with imag freqs | new `.gjf` (`Opt Freq`) | iterate until all real, then `gaussian-ir-raman` |
| `gaussian-tuned-omega` | 2-3 | ω-tuning for range-separated DFT (ωB97X-D, LC-ωPBE) | structure + ω grid | sweep `.gjf`s + final tuned-ω `.gjf` | `gaussian-tddft` |
| `gaussian-tddft` | 2-4 | Excited-state TDDFT / TDA | structure + n_states / spin options | one `.gjf` (`TD` or `TDA`) | `gaussian-tddft-analysis` |
| `gaussian-deltae` | 2-5 | ΔE / interaction / binding / counterpoise (BSSE) inputs | complex structure + fragment defs | complex `.gjf` + per-fragment `.gjf`s | `gaussian-deltae-analysis` |
| `gaussian-scan` | 2-6 | PES scan in 6 modes (relaxed / rigid / external / GIC / auto-GIC) | structure + scan coords | one or many `.gjf`s + manifest | `gaussian-scan-analysis` |
| `gaussian-parse-output` | 4-0 | Generic `.log/.out` parser: status, energies, geometry, freqs, HOMO/LUMO, charges | any Gaussian output | summary report | use specialised analyzers for richer reports |
| `gaussian-ir-raman` | 4-1 | IR / Raman + Lorentzian/Gaussian broadening + method/basis scaling factors | `.log` from `gaussian-freq` | scaled freq table + spectrum | (terminal) |
| `gaussian-tddft-analysis` | 4-2 | UV-vis spectrum + MO contributions + multi-calc comparison | `.log` from `gaussian-tddft` | UV-vis table, plot, optimised-state energies | (terminal) |
| `gaussian-deltae-analysis` | 4-3 | Assemble final ΔE / binding from multiple `.log`s | `.log`s from `gaussian-deltae` | binding-energy report (BSSE-corrected) | (terminal) |
| `gaussian-scan-analysis` | 4-4 | Energy vs scan coord, fit minima / TS, plot | `.log`s from `gaussian-scan` | scan plot + critical-point table | (terminal) |

All scripts live under `skills/<name>/scripts/<verb>.py` and run with plain
`python3` — no compiled wheels, no GPU, no LAMMPS. Most are stdlib-only;
`gaussian-structure-check` optionally imports RDKit / OpenBabel for SMILES at
runtime inside `try/except` blocks (never at module load), so RULE #0 is not
triggered.

---

## Data files (reference DBs)

Two skills ship reference tables that drive validation / defaults:

| Skill | File | Purpose | Env-var override |
|---|---|---|---|
| `gaussian-input-builder` | `data/functionals.txt` | DFT functional keyword aliases | `GAUSSIAN_FUNCTIONAL_DB` |
| `gaussian-input-builder` | `data/basis_sets.txt`  | Basis-set availability + element ranges | `GAUSSIAN_BASIS_DB` |
| `gaussian-input-builder` | `data/solvents.txt`    | Solvent dielectric constants for SCRF | `GAUSSIAN_SOLVENT_DB` |
| `gaussian-ir-raman`      | `data/vibrational_scaling.txt` | Method/basis → scale-factor lookup | `GAUSSIAN_SCALING_DB` |

All defaults are resolved at runtime via `Path(__file__)` so the scripts work
from any CWD. Override by setting the env var, or by passing the corresponding
CLI flag (`--basis-db`, `--scaling-db`, …).

Additionally, `gaussian-input-builder` cross-loads the `gaussian-structure-check`
script as a Python module (`importlib.util.spec_from_file_location`) to share
the structure-validation code. The path is resolved relative to the
`skills/` root and is overridable via `GAUSSIAN_STEP1_SCRIPT`.

---

## Typical usage

### Single-point energy on a SMILES

```bash
# 1. Pre-flight structure validation (RDKit/OpenBabel under the hood)
python3 skills/gaussian-structure-check/scripts/check_structure.py \
    --smiles "c1ccccc1" --name benzene

# 2. Build the .gjf
python3 skills/gaussian-sp/scripts/sp_workflow.py \
    --input benzene.xyz --method "wB97X-D" --basis "6-31G(d,p)" \
    --solvent toluene --state neutral

# 3. User runs Gaussian (separate, e.g. via SLURM — see steering/knowledge/gaussian.md)
sbatch run.slurm

# 4. Parse the output
python3 skills/gaussian-parse-output/scripts/parse_output.py benzene.log
```

### Frequency + IR spectrum

```bash
# 1. Build Opt+Freq input
python3 skills/gaussian-freq/scripts/freq_workflow.py \
    --input mol.xyz --method B3LYP --basis "6-311+G(d,p)" --opt

# 2. (user) g16 mol.gjf → mol.log

# 3. If imaginary modes appear, iterate via fix-imag
python3 skills/gaussian-fix-imag/scripts/fix_imaginary.py mol.log
#    → mol_fixed.gjf  → user runs Gaussian again → check again …

# 4. Once all real, generate IR spectrum with scaling
python3 skills/gaussian-ir-raman/scripts/ir_spectrum.py mol.log --use-scaling-factor
```

### TDDFT with ω-tuning (CT-prone chromophore)

```bash
python3 skills/gaussian-tuned-omega/scripts/tuned_omega.py \
    --input mol.xyz --functional "wB97X-D" --omega-grid "0.10,0.15,...,0.40"
#   → multiple .gjfs for the sweep + a final tuned-omega.gjf

# (user) runs the whole sweep on SLURM

python3 skills/gaussian-tddft/scripts/excited_state.py \
    --input mol.xyz --method "tuned-wB97X-D" --omega 0.183 \
    --nstates 20 --spin singlet

# (user) g16 tddft.gjf

python3 skills/gaussian-tddft-analysis/scripts/tddft_analysis.py tddft.log \
    --broadening lorentzian --fwhm 0.3
```

### Binding energy (counterpoise)

```bash
python3 skills/gaussian-deltae/scripts/deltae_workflow.py \
    --input complex.xyz --fragments "1-12,13-24" --counterpoise

# (user) runs the complex + 2 ghost-atom fragment jobs

python3 skills/gaussian-deltae-analysis/scripts/deltae_analysis.py \
    complex.log frag_A.log frag_B.log
```

### PES scan

```bash
# Relaxed dihedral scan in one Gaussian job
python3 skills/gaussian-scan/scripts/scan_workflow.py \
    --input mol.xyz --mode relaxed \
    --modredundant "D 1 2 3 4 S 36 10.0"

# (user) g16 scan.gjf

python3 skills/gaussian-scan-analysis/scripts/scan_analysis.py scan.log
```

See each skill's `SKILL.md` for the authoritative flag list.

---

## What these skills do NOT do

- **Do not run Gaussian.** No `subprocess` calls to `g16`, no SLURM submission.
  The user is responsible for execution. The canonical SLURM template is in
  [`steering/knowledge/gaussian.md`](https://github.com/avatsaev/pi-molagent/blob/main/steering/knowledge/gaussian.md).
- **Do not heavy-compute on the login node.** No NumPy/SciPy/Torch at module
  import. RULE #0 is not triggered by any quantum script.
- **Do not depend on the OPLS-AA / LAMMPS skills.** No shared lib code, no
  shared config. The two skillsets coexist but are fully isolated.

---

## Dependency / readiness

The extension's env-probe (`extension/env-check.ts → SKILL_REQUIREMENTS`)
declares **no binary dependencies** for any `gaussian-*` skill. They will
appear under `Ready skills:` on every host with Python 3.

Runtime dependencies (only required for the specific features that use them):

| Feature | Imports |
|---|---|
| `gaussian-structure-check --smiles` | RDKit *or* OpenBabel *or* `obabel` CLI |
| (everything else)                   | Python stdlib only |

If RDKit / OpenBabel are unavailable, `gaussian-structure-check` falls back
gracefully and asks the user to supply a coordinate file (`.xyz`, `.pdb`,
`.mol`, `.mol2`, `.sdf`, `.com`).

---

## Cross-references

- [`steering/knowledge/gaussian.md`](https://github.com/avatsaev/pi-molagent/blob/main/steering/knowledge/gaussian.md) —
  how to *run* Gaussian (g16 module, `%nprocshared`, `GAUSS_SCRDIR`, ω-tuning).
  Load in-session with `/gaussian`.
- [`steering/knowledge/hpc.md`](https://github.com/avatsaev/pi-molagent/blob/main/steering/knowledge/hpc.md) — partition
  selection, walltime, `va` / `job-limits` checks before every submit.
  Load with `/hpc`.
- [`docs/CONFIG.md`](#config) — molagent.json schema. No keys are required
  by `gaussian-*` skills; everything is CLI / env-var driven.
- Each skill's `SKILL.md` — authoritative flag list and per-skill design notes.

---

## Adding a new gaussian-* skill

1. Create `skills/gaussian-<name>/SKILL.md` with YAML frontmatter:

   ```yaml
   ---
   name: gaussian-<name>
   description: <30–80 words describing inputs, outputs, distinguishing features, sister skills>
   ---
   ```

2. Drop the executable at `skills/gaussian-<name>/scripts/<verb>.py`. Resolve
   any reference-data path via `Path(__file__).resolve().parent.parent / "data" / "..."`.

3. Register the skill in `extension/env-check.ts → SKILL_REQUIREMENTS` with its
   binary deps (typically `[]` — Gaussian itself is not a dep because these
   skills don't execute it).

4. Append a row to the catalogue table above.

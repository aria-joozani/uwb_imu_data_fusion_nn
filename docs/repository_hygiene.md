# Repository Hygiene and Dirty-Tree Classification

## Purpose

This record classifies the workspace that existed before the first repository-cleanup commit. It distinguishes source and scientific evidence that belong in Git from large local data, generated output, backups, and ambiguous third-party material. Cleanup is non-destructive: ignored files remain on disk.

This is a historical pre-organization record. The later responsibility-based move is documented in `file_organization.md`; paths in this document intentionally describe the state that was categorized before that move.

Audit basis:

- branch: `main`;
- starting commit: `a70cd2700fd1cd3fb1acf180033c5aed4327352b`;
- tracked changes: 9 modified MATLAB files and 2 deleted legacy LSTM files;
- untracked population: 1,446 files, approximately 1,377.85 MiB;
- audit date: 2026-08-30.

## Classification summary

| Category | Decision | Approximate scope | Reason |
|---|---|---:|---|
| Modified tracked research code | Commit as an explicitly documented experimental snapshot | 9 files | Preserves the user's existing work before later correctness fixes |
| Deleted LSTM source | Restore from `HEAD`; do not delete | 2 files | Checkpoint is still tracked and obsolescence/removal was not established |
| New MATLAB/Python research source | Commit | 19 files | Training, inference, solver, plotting, PTQ, and baseline utilities |
| Review/baseline documentation | Commit | 13 Markdown files including this record | Required scientific and architectural provenance |
| Compact model checkpoints | Commit | 5 root MAT files, all below 0.25 MiB | Needed to preserve the reviewed model identities and hashes |
| Legacy runner selection | Commit | `trials.mat`, 313 bytes | Small input expected by `infrence_runner.m`; retained even though the runner is currently ineffective |
| Historical baseline summaries | Commit | 4 XLSX source files and 3 generated CSV records | Small, machine-readable behavior-preservation evidence |
| Diagram sources and exports | Commit, excluding backups | 15 files, about 1.38 MiB | Thesis architecture assets with editable Draw.io sources |
| Reduced/generated datasets | Ignore, preserve locally | 38 CSV files, about 519.95 MiB | Regenerable/bulk data unsuitable for normal Git |
| Evaluation result tree | Ignore except four summary XLSX files | 1,321 files, about 566.26 MiB | Mostly generated FIG/PNG/TXT output |
| Large intermediates and archives | Ignore, preserve locally | PTQ MAT, RAR/ZIP archives | Generated or duplicate binary payloads |
| Root plots/logs/workbook copies | Ignore, preserve locally | PNG/FIG/XLSX/CSV outputs | Generated presentation and run artifacts |
| Editor/diagram backups | Ignore, preserve locally | `.asv` and `.bkp` files | Non-source temporary copies |
| Local scratch state | Ignore | empty `MEMORY.md` | Agent-local state, not project documentation |
| Legacy third-party `ieee.m` | Ignore pending provenance/license review | 1 file, about 22 KiB | Header attributes external 2005 authors; no license is present |

## Tracked experimental modifications preserved

These changes predated the review. They are committed to make the repository clean and to provide a stable starting snapshot, not to certify scientific correctness.

| Path | Category | Observed change | Review status |
|---|---|---|---|
| `dataset_generator.m` | Dataset behavior | Feature 109 changed from ideal previous TDoA to measured previous TDoA; progress dialogs closed | Material schema change; documented, not validated |
| `dataset_generator_runner.m` | Dataset selection | Output moved from `export-data-set` to `export-data-set-r`; loop begins at first file; progress text added | Includes a sixfold duplicate flight already flagged as leakage/weighting risk |
| `fusion_eskf.m` | Evaluation script | Different hard-coded flight, logging/figure output, and position MA reporting | MA formula duplicates x and omits z; preserved as known defect |
| `inference.m` | Evaluation script | 21-flight list, model/output selection, per-pair metrics, MA metrics, and saved figures | Target-row alignment and MA formula defects documented |
| `src/eskf/ESKF.m` (then `library/ESKF.m`) | Algorithm tuning | Acceleration/gyro noise changed from 2/0.1 to 0.1/0.01 | Numerical behavior change; provenance and validation unknown |
| `src/preprocessing/downsamp.m` (then `library/downsamp.m`) | Preprocessing behavior | Enabled three factor-2 reductions (overall factor 8) | Numerical/data-rate change; current reduced datasets reflect it |
| `src/visualization/plot_pos.m` (then `library/plot_pos.m`) | Presentation | Added stable figure name `pos` | Behavior-preserving plotting metadata |
| `src/visualization/plot_pos_err.m` (then `library/plot_pos_err.m`) | Presentation | Added stable figure name `pos_error` | Behavior-preserving plotting metadata |
| `src/visualization/plot_traj.m` (then `library/plot_traj.m`) | Presentation | Added stable figure name `traj` | Behavior-preserving plotting metadata |

The experimental modifications are intentionally not repaired in the cleanup commit. Correctness fixes require separate tests and separate commits so scientific differences remain attributable.

## Restored research code

`inference_lstm.m` and `train_tdoa_lstm_net.m` were deleted in the starting worktree. They are restored unchanged from `HEAD` because:

- `networks/trained_tdoa_net_lstm.mat` remains tracked;
- the LSTM architecture is discussed in the review;
- no reference audit or replacement demonstrates that deletion is safe;
- the master refactoring rules prohibit premature removal of research code.

They remain classified as legacy and are not part of the baseline evaluation.

## New source committed

### Evaluation and inference

- `inference_tdoa.m`
- `inference_timesequnce.m`
- `infrence_runner.m` (legacy misspelling retained to avoid an untested rename)
- `run_baseline_evaluation.m`

### Training and deployment

- `train_tdoa_net1.m`
- `train_tdoa_cnn_net1.m`
- `train_tdoa_cnn_net2.m`
- `train_tdoa_cnn_net3.m`
- `prepare_data_for_ptq.m`
- `ptq_tdoa_net.m`
- `exportNetwork.m`

### Solvers and visualization

- `src/localization/solve_tdoa_nls_2d.m`
- `src/localization/solve_tdoa_nls_3d.m`
- `src/localization/tdoa_residuals_3d.m`
- `plot_anchors_3d.m`
- `plot_position_rms.m`
- `plot_rms_ma.m`
- `plot_sampling_timeline.m`
- `uwb_imu_pipeline_diagram.py`

Several files contain known issues recorded in `code_review.md`, including the opposite NLS TDoA sign, invalid duplicate CNN3 layer names, leakage-prone splitting, and hidden script state. Committing them preserves the research snapshot; it does not promote them to validated interfaces.

## Scientific artifacts committed

### Root model checkpoints

- `trained_tdoa_net_5.mat`
- `trained_tdoa_net_fcc1.mat`
- `trained_tdoa_net_cnn_1.mat`
- `trained_tdoa_net_cnn_2.mat`
- `trained_tdoa_net_cnn_3.mat`

All are small enough for ordinary Git. Exact SHA-256 identities are recorded in `baseline_results.md` and `neural_network_review.md`. Existing checkpoints in `networks/` were already tracked and remain unchanged.

`trials.mat` is also retained as the small legacy input loaded by `infrence_runner.m`. The review documents that `inference.m` clears and replaces its values, so this is preservation rather than endorsement of the runner design.

### Baseline artifacts

The four source workbooks retained under `result/` are:

- `result_overall_tdoa_ma.xlsx`
- `result_overall_tdoa_rms.xlsx`
- `result_position_ma.xlsx`
- `result_position_rms.xlsx`

The reproducible reconstruction outputs retained under `results/` are the three CSV files. `results/baseline_results.mat` is generated and ignored because it duplicates the CSV content in a binary MATLAB container.

## Local-only artifacts and ignore rules

The updated `.gitignore` maps every remaining untracked family:

| Pattern/family | Local content |
|---|---|
| `/csv-data/`, `/export-data-set/`, `/export-data-set-r/`, `/survey-results/` | raw data, generated training data, and survey inputs |
| `/result/*` with four XLSX exceptions | per-run figures, logs, plots, and position workbooks |
| `/saved_figures/` | generated figure collection |
| `/results/*.mat` | regenerated binary baseline container |
| `/*.fig`, `/*.png`, `/*.xlsx`, `/training_log*.csv` | root-level generated plots, duplicate summaries, and append-only logs |
| `/prepared_data_for_ptq.mat`, `/net2_training_data.mat` | large generated calibration/training tensors |
| `*.rar`, `*.zip` | dataset, network, library, and repository archives |
| `*.asv`, `*.bkp` | MATLAB autosaves and Draw.io backups |
| `/MEMORY.md` | local scratch state |
| `/ieee.m` | externally attributed legacy channel simulation pending license decision |

No ignored file is removed, moved, or rewritten by this cleanup.

## Pre-commit validation record

- MATLAB `checkcode` scanned 48 MATLAB files and reported 63 existing findings. Forty-one belong to ignored third-party `ieee.m`; the remaining findings are in legacy/experimental scripts already covered by `code_review.md`.
- `run_baseline_evaluation.m` has no `checkcode` findings.
- The deterministic baseline smoke test passed with 21 flights, 336 long-form rows, and 576 grouped summary rows.
- The largest new commit candidate is about 306 KiB, well below ordinary Git hosting limits.
- No full training or live inference run was attempted during repository hygiene because the saved historical pipeline is not noninteractive or provenance-complete.

## Repository-clean acceptance criteria

The cleanup is complete only when:

1. the intended source, documentation, checkpoints, diagrams, and compact baseline evidence are staged;
2. no staged file exceeds normal Git-hosting limits;
3. MATLAB static checks and the baseline smoke test complete;
4. `git diff --check` reports no whitespace errors;
5. the cleanup commit succeeds;
6. `git status --short` is empty after the commit.

Ignored bulk data remain necessary for full experiments. A clean Git status therefore means the repository metadata is organized, not that the local workspace contains only tracked files.

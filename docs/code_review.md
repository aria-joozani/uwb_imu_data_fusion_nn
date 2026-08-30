# Code review

## Scope and method

This is a review of the effective working tree, not only Git HEAD. Evidence came from source inspection, raw/generated CSV metadata, saved MATLAB model metadata, existing result tables and logs, Git history/diffs, and MATLAB R2025b Code Analyzer. No scientific algorithm was edited and no model was retrained.

Priority meanings:

- **P0 - Scientific correctness:** can change research conclusions or the meaning of a reported metric.
- **P1 - Reliability:** can make a run wrong, irreproducible, or fail.
- **P2 - Maintainability:** makes safe extension and review difficult.
- **P3 - Style:** readability or naming only.

## Executive assessment

The repository contains a coherent research idea and enough artifacts to recover the main pipeline, but it does not currently support an auditable baseline run. The highest risks are not MATLAB style issues. They are split leakage, prediction/target alignment, metric identity, uncommitted behavior changes, and mathematically sensitive ESKF behavior.

The quoted headline baseline is recoverable from the Excel files, but it is a mean of per-flight **TDoA** errors. The final ESKF position table contains materially different values and model rankings. Until this distinction and the split methodology are settled, the existing headline should not be presented as independently reproduced position accuracy.

## Findings summary

| ID | Priority | Finding | Main locations |
| --- | --- | --- | --- |
| SCI-01 | P0 / CRITICAL | Sample-level random split and full-dataset normalization leak correlated flight data across train/validation/test | all `train_tdoa_*.m` scripts |
| SCI-02 | P0 / CRITICAL | Many nominal 21 evaluation flights are explicitly included in model training lists | FNN/CNN training lists versus `inference.m` |
| SCI-03 | P0 | Headline baseline values are TDoA errors, not the final position errors implied by the prompt | `result_overall_tdoa_*.xlsx`, `result_position_rms.xlsx` |
| SCI-04 | P0 | Baseline inference stores a prediction for the next same-pair epoch at a sequential/current UWB row | `dataset_generator.m`, `inference.m` |
| SCI-05 | P0 | Overall position MAE omits z and counts x twice | `fusion_eskf.m`, `inference.m` |
| SCI-06 | P0 | Active NLS TDoA residual uses the opposite sign convention from data generation and ESKF | `library/tdoa_residuals_3d.m`, `inference_tdoa.m` |
| SCI-07 | P0 review required | Integrated timeline assigns measurements found at `t(k-1)` to row `k`/time `t(k)`; ESKF corrects after propagating to `t(k)` | generation, inference, and fusion scripts |
| SCI-08 | P0 review required | ESKF rotation matrix used in propagation lags the stored quaternion; attitude injection lacks an explicit covariance reset | `library/ESKF.m` |
| SCI-09 | P0 / HIGH | Downsampling and ESKF process noise have uncommitted behavior changes with no regression record | `library/downsamp.m`, `library/ESKF.m` |
| REL-01 | P1 | No single reproducible baseline/evaluation entry point | repository-wide |
| REL-02 | P1 | Model identity is ambiguous across same-named root and `networks/` checkpoints | model files and inference scripts |
| REL-03 | P1 | Training definitions contain known runtime defects | `train_tdoa_net.m`, `train_tdoa_cnn_net3.m` |
| REL-04 | P1 | Base-workspace scripts, `clear all`, and hard-coded paths create hidden dependencies | most root scripts |
| REL-05 | P1 | Dataset list duplicates one flight six times, weighting it sixfold during training | training and PTQ file lists |
| REL-06 | P1 | Column-wise NaN deletion can silently desynchronize fields | `extract_*.m`, `deleteNAN.m` |
| REL-07 | P1 | Existing logs/results are mutable and not tied to configs or model hashes | `result/`, root XLSX files |
| REL-08 | P1 | Random seeds are uncontrolled | training and PTQ scripts |
| REL-09 | P1 | No automated or numerical regression tests exist | repository-wide |
| MAIN-01 | P2 | Dataset integration and feature construction are copied across multiple scripts | generation and three inference scripts |
| MAIN-02 | P2 | Metrics and plotting are duplicated and definitions differ | fusion/inference/plot scripts |
| MAIN-03 | P2 | Repository hygiene and artifact provenance are weak | `.gitignore`, archives, models, results |
| MAIN-04 | P2 | Obsolete and experimental code is mixed with active code | `ieee.m`, deleted LSTM source, alternative inference scripts |

## Detailed scientific findings

### SCI-01 - Full-dataset normalization and sample-level split

**Finding:** Every active FNN/CNN training script calculates `zscore(X)` and `zscore(Y)` before the split, then applies `randperm` to individual epochs.

**Location:** `train_tdoa_net.m`, `train_tdoa_net1.m`, `train_tdoa_cnn_net.m`, `train_tdoa_cnn_net1.m`, `train_tdoa_cnn_net2.m`, and `train_tdoa_cnn_net3.m`.

**Risk:** P0 / CRITICAL.

**Why suspicious:** Validation/test distribution statistics affect training normalization. More importantly, adjacent epochs from the same flight are strongly correlated and can be divided among all three splits. The feature target is based on the next occurrence of the same pair, so neighboring rows also share temporal context.

**Observed behavior:** Global means/standard deviations are saved in each model checkpoint. No flight identifier survives into the split, and no seed is set.

**Recommended change:** First reproduce and freeze this as `legacy_random_epoch` behavior. Then add an explicitly different group-based split that fits normalization on training flights only and applies those statistics unchanged to validation/test.

**Expected impact:** A leakage-safe result may be worse than the legacy table; that difference is scientifically meaningful and must not be hidden.

**Verification:** Assert disjoint flight IDs and non-overlapping source windows, recompute normalization from train groups only, and report both legacy and group-held-out experiments.

### SCI-02 - Evaluation flights appear in training inputs

**Finding:** The current FNN/CNN1/CNN2 source lists include 15 of the 21 const4 evaluation flights. Older CNN training sources include 18 of 21.

**Location:** CSV lists in training scripts compared with the 21-flight list in `inference.m`.

**Risk:** P0 / CRITICAL.

**Why suspicious:** “Test flight” performance is not held-out generalization if the same flight supplied training epochs.

**Observed behavior:** The newer lists include const4 trials 1, 2, 3, and 6 and all three manual flights; they omit trials 4 and 5. Older lists also include trial 4. No source documents a deliberate train-versus-evaluation policy.

**Recommended change:** Do not relabel or overwrite the thesis baseline. Document its actual split as `UNKNOWN/legacy`, then add flight-, trajectory-, and constellation-grouped experiments.

**Expected impact:** Changes the interpretation, not necessarily the arithmetic, of the existing results.

**Verification:** Emit a split manifest containing every source flight and fail if any evaluation flight is present in training.

### SCI-03 - Baseline metric identity is mislabeled

**Finding:** The prompt's quoted RMS/MAE values and 19-of-21 statement exactly match TDoA error summaries, not position summaries.

**Location:** `result_overall_tdoa_rms.xlsx`, `result_overall_tdoa_ma.xlsx`, and `result_position_rms.xlsx`.

**Risk:** P0.

**Why suspicious:** Calling a scalar range-difference error “position error” changes the claimed research outcome.

**Observed behavior:** Mean TDoA RMSE is 0.392157/0.293181/0.282990/0.291595 m and CNN1 wins 19/21. Mean ESKF position RMSE is 0.502481/0.335681/0.324914/0.329262 m and model win counts are 7/8/6 for FNN/CNN1/CNN2.

**Recommended change:** Give every metric an explicit domain: `tdoa_rmse_m`, `tdoa_mae_m`, `position_rmse_3d_m`, and so on. Resolve the intended thesis claim with the researcher before editing narrative results.

**Expected impact:** Prevents reporting the correct number under the wrong physical meaning.

**Verification:** Generate both tables from one evaluator and unit-test their definitions on synthetic errors.

### SCI-04 - Neural prediction-to-UWB alignment

**Finding:** A feature row starts at pair occurrence `k`, finds the next same-pair occurrence `l`, and targets the ideal TDoA at `l`. Baseline `inference.m` appends that prediction as `uwb_enhanced(m)` and later compares/replaces UWB row `m`, not the UWB row corresponding to `l`.

**Location:** `dataset_generator.m` feature/target construction and `inference.m` lines that assign `uwb_enhanced(m)` and later replace all UWB rows.

**Risk:** P0.

**Why suspicious:** With eight ring pairs, the target is typically about eight aggregate UWB rows later (about 0.13 s for the representative flight after downsampling). A model can be evaluated against the wrong ground-truth epoch.

**Observed behavior:** `inference_timesequnce.m` contains a more explicit `uwb_row_at_time(target_idx)` mapping, but the baseline `inference.m` does not. `inference_tdoa.m` creates a mapping but still fills outputs sequentially.

**Recommended change:** First create a regression fixture for legacy sequential assignment. Then implement target-row assignment as a separately labeled `BEHAVIOR CHANGE` experiment.

**Expected impact:** Can materially change both TDoA and final position metrics.

**Verification:** On synthetic pair timestamps, assert each prediction is attached to `l`, and compare legacy versus corrected results per pair and flight.

### SCI-05 - Incorrect aggregate position MAE

**Finding:** `ma_all` is calculated from `ma_x + ma_y + ma_x`; z is omitted and x is duplicated.

**Location:** `fusion_eskf.m` and `inference.m`.

**Risk:** P0 if this value is reported.

**Why suspicious:** The formula is arithmetically wrong even for an axis-sum definition, and an axis-sum is different from mean Euclidean position error.

**Observed behavior:** Per-axis MAEs are calculated correctly immediately beforehand. `result/result_position_ma.xlsx` contains only NaNs, so no trustworthy consolidated position-MAE baseline exists.

**Recommended change:** Preserve the legacy printed value only for comparison. Define and test both `mean(abs(error), axis)` and `mean(vecnorm(error,2,2))`; select the thesis definition explicitly.

**Expected impact:** Corrected position MAE will differ from logged values.

**Verification:** Synthetic errors with distinct x/y/z values must detect the x-for-z typo and distinguish axis-sum from Euclidean MAE.

### SCI-06 - TDoA sign mismatch in NLS path

**Finding:** Dataset generation and ESKF use `d_B - d_A`; `tdoa_residuals_3d.m` predicts `d_A - d_B` for the same pair ID ordering.

**Location:** `generate_tdoa_from_gt.m`, `ESKF.UWB_correct`, `tdoa_residuals_3d.m`, and the duplicated local residual in `inference_tdoa.m`.

**Risk:** P0 for the TDoA-only localization experiment; it is not on the current ESKF baseline path.

**Why suspicious:** Opposite measurement conventions generally reflect/misplace an NLS solution or force a poor residual fit.

**Observed behavior:** The NLS helpers are untracked and no synthetic solver test exists.

**Recommended change:** Add a known-position synthetic test before changing the sign. Then make pair convention explicit in one shared measurement function.

**Expected impact:** Behavior change isolated to TDoA-only localization.

**Verification:** Generate ideal measurements from a known transmitter and recover that location within a documented tolerance.

### SCI-07 - Event-time indexing requires an explicit decision

**Finding:** Integration loops iterate `k = 2:K`, search for data at `t(k-1)`, but store it in row `k`, whose time column is `t(k)`. ESKF prediction uses the `t(k-1)` IMU sample to propagate over `dt = t(k)-t(k-1)` and applies a `t(k-1)` UWB sample after that propagation.

**Location:** `dataset_generator.m`, `inference.m`, `inference_tdoa.m`, `inference_timesequnce.m`, and `fusion_eskf.m`.

**Risk:** P0 review required.

**Why suspicious:** The IMU convention may be a deliberate zero-order event update, but labeling the stored measurement with the next union timestamp and delaying UWB correction is not documented. Feature interpolation uses these shifted row timestamps.

**Observed behavior:** The representative streams have millisecond-scale event gaps. Exact values are copied from the original timestamp vectors, so equality lookup itself succeeds, but semantic time alignment remains ambiguous.

**Recommended change:** Write a synthetic event-timeline test and document whether inputs are left-endpoint, right-endpoint, or instantaneous. Do not alter indexing until current behavior is captured.

**Expected impact:** A correction could change every generated feature and all filter results.

**Verification:** Use two short sensor sequences with distinct timestamps/values and assert the intended update time for each event.

### SCI-08 - ESKF attitude propagation/reset concerns

**Finding:** `obj.R` is set from `q_{k-1}` after `q_k` has been computed, so the next propagation uses a rotation older than the stored previous quaternion. The measurement update injects a small-angle quaternion but does not perform an explicit covariance reset Jacobian.

**Location:** `library/ESKF.m` prediction lines around quaternion/rotation updates and `UWB_correct` attitude injection.

**Risk:** P0 review required.

**Why suspicious:** Rotation lag changes acceleration projection and covariance Jacobians. Error-state injection normally requires the implementation's covariance/reset convention to be explicit.

**Observed behavior:** Quaternion multiplication is used without an explicit normalization call; covariance is symmetrized, but the simple `(I-KG)P` update is not Joseph form. `R_list(1,:,:)` is not initialized. Comments around `G_dx` report incorrect dimensions even though the matrix multiplication produces a 1x9 Jacobian.

**Recommended change:** Complete the mathematical ESKF review and build stationary/constant-rate synthetic tests before any correction. Separate each mathematical fix from structural refactoring.

**Expected impact:** Potentially material position changes.

**Verification:** Check quaternion norm, covariance symmetry/positive semidefiniteness, stationary gravity cancellation, known-rate attitude, finite-difference measurement Jacobian, and before/after flight regression.

### SCI-09 - Uncommitted scientific behavior changes

**Finding:** Relative to Git HEAD, `downsamp` changed from no downsampling to three factor-2 passes, and ESKF process-noise constants changed from 2/0.1 to 0.1/0.01. Dataset feature 109 changed from ideal/ground-truth TDoA to measured TDoA.

**Location:** current Git diff in `library/downsamp.m`, `library/ESKF.m`, and `dataset_generator.m`.

**Risk:** P0 / HIGH.

**Why suspicious:** These are behavior changes, not refactors, and there is no configuration or baseline record tying them to the February 2026 checkpoints/results.

**Observed behavior:** Root checkpoints share normalization statistics consistent with one generated-data family, but source/artifact provenance is not recorded.

**Recommended change:** Treat the current working tree as an evidence snapshot. Hash model/data/result artifacts and reproduce both the current and Git-HEAD configurations only after explicit configuration fields exist.

**Expected impact:** Determines which source version can reproduce which checkpoint/result.

**Verification:** Record Git diff hash, artifact hashes, preprocessing flags, and per-flight metrics for every baseline run.

## Reliability findings

### REL-01 - No auditable baseline runner

**Finding:** Evaluation requires editing hard-coded script variables and manually transferring results.

**Risk:** P1.

**Observed behavior:** `inference.m` evaluates one flight and one currently hard-coded FNN. `infrence_runner.m` sets variables, but `inference.m` immediately clears and overwrites them. No script loops through 21 flights x models and writes the Excel tables.

**Recommended change:** Introduce `run_baseline_evaluation(config)` only after wrapping current stages in functions. Save per-flight predictions and long-form metrics with model/data hashes.

**Verification:** A clean MATLAB session must regenerate one machine-readable 21-flight table without editing source.

### REL-02 - Ambiguous checkpoint identity

**Finding:** Root and `networks/` contain different models with overlapping CNN names.

**Risk:** P1.

**Observed behavior:** Root CNN1 has 12 layers; `networks/CNN1` has 16. Root CNN2 has 22 layers; `networks/CNN2` has 17. Statistics also differ.

**Recommended change:** Use immutable model IDs and a manifest containing path, SHA-256, architecture summary, training config, data manifest, and normalization hash.

**Verification:** The evaluator refuses an unregistered or shape-incompatible checkpoint.

### REL-03 - Broken training definitions

**Finding:** `train_tdoa_net.m` references undefined `XVal`/`YVal`, and `train_tdoa_cnn_net3.m` repeats `conv4`, `bn4`, and `relu4` layer names.

**Risk:** P1.

**Observed behavior:** Saved checkpoints exist, but the current sources do not cleanly define how all of them were produced.

**Recommended change:** Add construction-only smoke tests for every registered model and do not overwrite historical checkpoints.

**Verification:** Build/analyze each network without loading the full dataset, then run a one-batch training smoke test.

### REL-04 - Hidden workspace state and hard-coded paths

**Finding:** Root workflows are scripts that depend on variables created by other scripts and begin with `clear all`/`clearvars`.

**Risk:** P1.

**Observed behavior:** `data_extractor.m` requires `csv_file` and `anchors`; `dataset_generator.m` additionally requires `export_csv_file` and all extractor outputs. Paths, trial indices, model files, output directories, thresholds, and filter parameters are embedded in code.

**Recommended change:** Convert one stage at a time to functions with explicit inputs/outputs and a validated config struct.

**Verification:** Unit calls work from a clean workspace and do not depend on path or call order.

### REL-05 - Duplicate file weighting

**Finding:** `const4-trial1-tdoa2-traj1_NN.csv` appears six times in the 43-entry training and PTQ lists.

**Risk:** P1, potentially P0 if accidental weighting affects conclusions.

**Observed behavior:** Concatenation makes that flight six times as influential as an ordinary listed flight. The dataset-generation runner also repeats and overwrites the same output six times.

**Recommended change:** Validate uniqueness. If weighting is intentional, encode it explicitly as a named weight rather than duplicate paths.

**Verification:** Manifest validation reports duplicates and effective per-flight sample weights.

### REL-06 - Independent NaN deletion

**Finding:** Each extractor removes NaNs from timestamp and value columns independently before horizontal concatenation.

**Risk:** P1.

**Observed behavior:** Current raw files appear designed with matching sparse masks, but a single partial missing value would shift a channel relative to its timestamp or make concatenation fail.

**Recommended change:** Apply one row mask per sensor record across timestamp and all fields, with assertions.

**Verification:** Synthetic partial-NaN tables must either preserve row alignment or fail with a precise diagnostic.

### REL-07 - Mutable result provenance

**Finding:** Diaries and figures are stored under manually selected directories without configuration/model hashes; logs contain repeated runs and at least one 791.8428 m outlier followed later by a 0.2656 m run in the same file.

**Risk:** P1.

**Observed behavior:** Root and `result/` Excel summaries are duplicated; `result/result_position_ma.xlsx` is all NaN. Result artifacts are untracked and not ignored consistently.

**Recommended change:** Make each run directory immutable and self-describing: config, environment, hashes, metrics, predictions, log, and figures.

**Verification:** A summary row links to exactly one run manifest and checkpoint hash.

### REL-08 - Uncontrolled randomness

**Finding:** Training and PTQ use `randperm` without `rng(seed)`; model initialization and shuffling are also uncontrolled.

**Risk:** P1.

**Recommended change:** Put the seed in config, call `rng` once at the experiment boundary, and record RNG state.

**Verification:** Repeated CPU runs produce identical split manifests and sufficiently equivalent metrics.

### REL-09 - No tests

**Finding:** No `tests/` directory or MATLAB unit tests exist.

**Risk:** P1.

**Recommended change:** Start with metrics, pair convention, target alignment, synchronization, feature ordering, normalization reuse, and ESKF invariants. Add a small immutable regression fixture before refactoring active scripts.

**Verification:** `runtests('tests')` is the required gate for each refactor stage.

## Maintainability and hygiene findings

- **P2:** Integration and 17-sample feature construction are duplicated across `dataset_generator.m`, `inference.m`, `inference_tdoa.m`, and `inference_timesequnce.m`; the variants have already diverged in target alignment and history behavior.
- **P2:** Metric formulas are repeated rather than centralized. “RMS,” “RMSE,” scalar TDoA RMSE, axis RMSE, 3-D RMSE, and position MAE are not named consistently.
- **P2:** The current `.gitignore` ignores only three paths. Large generated datasets, 1,170 FIG files, root checkpoints, archives, spreadsheets, auto-save files, and training logs are untracked but unclassified.
- **P2:** `library/downsamp.m` contains a second local `isin` implementation while `library/isin.m` also exists.
- **P2:** `ieee.m` is a separate stochastic IEEE channel-model implementation with no active references. It should be classified/archived only after provenance review, not deleted.
- **P2:** Root, `networks/`, and archives hold multiple model generations with no manifest.
- **P2:** GUI progress dialogs make batch/headless evaluation harder and mix computation with presentation.
- **P3:** Misspellings such as `infrence`, `timesequnce`, `intgrate`, `dateset`, `sreach`, `Ma`, `manula`, and `ccn_2` impede discovery but should be corrected only in small, behavior-neutral changes.

## MATLAB Code Analyzer evidence

MATLAB R2025b Code Analyzer confirmed, among other items:

- loop variables `k` are assigned inside `for` loops even though MATLAB's next iteration overwrites those assignments;
- repeated use of `clear all`;
- an unreachable branch in `inference_tdoa.m`;
- dynamic growth and obsolete random APIs in the standalone `ieee.m`;
- redundant assignment and duplicate local `isin` in `downsamp.m`.

Code Analyzer does not prove scientific correctness and did not detect the undefined validation variable or duplicate network-layer names, so it is supplementary evidence only.

## Review conclusion

Major algorithmic refactoring should not begin yet. The next safe work is to finish the required data-flow, frame, leakage, mathematics, ESKF, and neural-model documents; capture artifact provenance; build tests that demonstrate the P0 issues; and establish a legacy-compatible evaluator. Corrections to leakage, alignment, metrics, signs, or ESKF equations must be separate, explicitly labeled behavior changes.

# Neural-Network Review

## Executive finding

The repository trains scalar TDoA regressors using a fixed 110-feature vector. It does not train an end-to-end position network. The saved FNN and CNN checkpoints are loadable, but their exact data lineage is not reconstructable from source: scripts use leaked random row splits, some evaluation flights are included in training, one flight is duplicated six times, seeds are absent, and current source architectures do not always match saved artifacts.

No network was retrained and no checkpoint was modified during this review.

## Learning task

One sample represents the interval between two consecutive observations of the same ordered anchor pair. The input is

- 17 time-major IMU samples x 6 axes = 102 values;
- ordered anchor A and B positions = 6 values;
- previous and current measured TDoA = 2 values.

The output is one ideal range difference, in metres, at the current/later event:

\[
y=\|p^{GT}-a_B\|-\|p^{GT}-a_A\|.
\]

The network therefore performs supervised TDoA enhancement. Position improvement is an indirect downstream result obtained when enhanced TDoA is supplied to NLS or ESKF.

Feature 109 is named `uwb_tdoA_last_gt`, but the working-tree generator writes a measured value. Git `HEAD` wrote an ideal/ground-truth value. Models trained under these two definitions solve different tasks even though input width and header remain identical.

## Dataset population seen by active scripts

The active reduced dataset directory contains 38 unique generated CSV files and 269,535 physical rows. Current training lists contain 43 entries and concatenate 306,055 rows because `const4-trial1-tdoa2-traj1_NN.csv` is listed six times. That one flight therefore receives sixfold sampling weight.

The evaluated const4 suite contains 21 flights. Current model lists also include 15 of those flights: const4 trials 1, 2, 3, and 6 (three trajectories each), plus all three manual flights. Older scripts additionally include trial 4. Only trial 5 is consistently evaluation-only among the regular trajectories.

See `dataset_structure.md` for the file-level inventory and `data_leakage_review.md` for split designs.

## Preprocessing and split

The active scripts follow this order:

1. concatenate all named files;
2. remove nonfinite rows;
3. z-score all X and Y using the complete dataset;
4. create an unseeded `randperm` over individual rows;
5. split 70%/15%/15% into train/validation/test;
6. train with shuffled mini-batches.

This has three distinct problems:

- validation and test distributions influence normalization;
- adjacent, overlapping windows from one flight are scattered across all splits;
- evaluation flights are also training sources.

The internal test RMSE printed by the scripts is therefore not an independent generalization estimate. A legitimate split must occur by flight/group before fitting normalization, with the manifest and RNG seed saved.

## Source model definitions

| Script | Family | Main architecture | Output | Optimizer/configuration | Source status |
|---|---|---|---:|---|---|
| `train_tdoa_net1.m` | FNN1 | 110 -> FC128/ReLU -> FC64/ReLU -> FC1 | 1 | Adam, lr 1e-3, 100 epochs, batch 8192, piecewise x0.5/10 epochs | Runnable in principle; leaky split |
| `train_tdoa_net.m` | FNN experiment | larger/different FNN in current source | 1 | Adam, lr 1e-2, 40 epochs, batch 256 | Broken: references undefined `XVal`/`YVal` |
| `train_tdoa_cnn_net1.m` | CNN1 | input 110x1; conv 9x1/16; pool; conv 5x1/32; FC32; FC1 | 1 | Adam, lr 1e-3, 50 epochs, batch 8192 | Leaky split |
| `train_tdoa_cnn_net2.m` | CNN2 | kernels 20/10/5/3; channels 8/16/32/64; three pools; FC64/32/1 | 1 | Adam, lr 1e-3, 100 epochs, batch 8192 | Leaky split |
| `train_tdoa_cnn_net3.m` | CNN3 | kernels 40/20/10/5/3; channels 8/16/32/64/64; FC64/32/1 | 1 | Adam, lr 1e-3, 50 epochs, batch 8192 | Invalid source: duplicate `conv4`, `bn4`, `relu4` names |
| `train_tdoa_cnn_net.m` | older CNN | alternative convolution/dropout design | 1 | Adam, lr 1e-3, 50 epochs, batch 8192 | Historical/ambiguous |

All use regression MSE and no input-layer normalization because z-scoring is performed outside the network. Validation frequency is 100 iterations and active scripts use patience 30. No `rng(seed)` call is present.

The preserved legacy LSTM source reshapes a concatenated row stream into length-20 sequences. Because file boundaries are not preserved, a sequence can cross from one flight into another. The LSTM checkpoint must be considered historical until its training pipeline is reconstructed safely.

## Saved checkpoint inspection

The following describes the checkpoints now organized under `models/active/`, as loaded by MATLAB R2025b during this review. Hashes identify the exact artifacts; they do not prove training provenance.

| Checkpoint | Loaded architecture | SHA-256 |
|---|---|---|
| `models/active/trained_tdoa_net_5.mat` | FNN 110 -> 128 -> 64 -> 1, ReLU | `CA2D796C4C85EA327DA141E297E8192A80D51571E64D5203A084A4C369797884` |
| `models/active/trained_tdoa_net_fcc1.mat` | FNN 110 -> 128 -> 64 -> 1, ReLU | `ACFA6EEB66861189C093F020F7CEA0761FB6CFD86F433E4541871C5D83703405` |
| `models/active/trained_tdoa_net_cnn_1.mat` | 12-layer CNN: conv 9/16, pool, conv 5/32, FC32, output | `8AFB50E2F5DC75D657ED9A8EBCA8AE4C4DCB649E9BDC563D73B2314434CBB55B` |
| `models/active/trained_tdoa_net_cnn_2.mat` | 22-layer CNN: kernels 20/10/5/3, channels 8/16/32/64, FC64/32 | `BC733D4ECB332FE180B11C11A8DB139D908F93665A208FBE7045D6BAD5FA774D` |
| `models/active/trained_tdoa_net_cnn_3.mat` | 26-layer CNN: kernels 40/20/10/5/3, channels 8/16/32/64/64, FC64/32 | `0BC92B3410954CB066EEB0AFCFD340645A86F16B6D9EEFB62BEF3210FFA1F8A5` |

The saved CNN3 has unique, automatically suffixed layer names and is loadable, while the current script repeats explicit names. Thus the checkpoint was not produced by the source exactly as it stands.

The `models/legacy/` directory holds additional, architecturally different files with overlapping model names, including an LSTM. There is no authoritative registry mapping thesis labels such as “CNN1” to one path, hash, generator version, split, or training run.

Normalization statistics also separate the active checkpoints into different populations. CNN1, CNN2, and FCC1 share one statistics set; `trained_tdoa_net_5.mat` and CNN3 use another. The exact source manifests that produced either set are **UNKNOWN**.

## Inference paths

### `inference.m`

The script builds a feature for source UWB row `k` and later same-pair target row `l`, predicts the target TDoA, but writes it sequentially to `uwb_enhanced(m)`. It then aligns that array with aggregate UWB row `m`. With an eight-pair ring, the predicted value is typically assigned several aggregate events earlier than its target.

This timing defect can invalidate both headline TDoA and downstream position comparisons. It must be demonstrated with an index-only unit fixture before correction.

The script also loads fixed checkpoint filenames internally and starts with `clear`; values set by `infrence_runner.m` do not reliably configure it.

### `inference_timesequnce.m`

This newer path keeps a target-row mapping and assigns `tdoa_corr(target_idx)` to the corresponding UWB row. Missing predictions fall back to the raw observation. This is structurally safer, although its metrics and experiment provenance still need consolidation.

### PTQ/export

`prepare_data_for_ptq.m`, `ptq_tdoa_net.m`, and `exportNetwork.m` form a deployment experiment path. The data-preparation script repeats the row-level random split assumptions and must use the eventual frozen manifest. There is no checked-in equivalence report comparing floating-point, quantized, and exported predictions on the same samples.

## Reported artifacts versus defensible claims

Existing spreadsheets summarize 21 const4 evaluation flights. Recalculation of their stored values gives:

| Metric | Raw | FNN/FCC1 | CNN1 | CNN2 |
|---|---:|---:|---:|---:|
| Mean per-flight TDoA RMSE (m) | 0.392157 | 0.293181 | 0.282990 | 0.291595 |
| Mean per-flight TDoA MAE (m) | 0.228557 | 0.183414 | 0.169762 | 0.182300 |
| Mean per-flight position RMSE (m) | 0.502481 | 0.335681 | 0.324914 | 0.329262 |

These are historical artifact summaries, not reproducible benchmark results, because:

- evaluated flights overlap training sources;
- the primary inference alignment is suspect;
- checkpoint/data/split provenance is absent;
- different spreadsheets and result directories can be overwritten by reruns;
- position MA code contains a formula defect;
- at least one log contains both an extreme intermediate value and a later plausible value.

The numbers may be useful as a legacy regression target, but they should not support a thesis generalization claim until regenerated under a leakage-safe protocol.

## Reproducibility gaps

| Gap | Consequence | Required artifact |
|---|---|---|
| No random seed | Every row split and training order can differ | saved RNG algorithm/seed/state |
| No flight manifest | Training and evaluation membership is ambiguous | immutable CSV/JSON manifest with group IDs |
| Normalization fitted before split | optimistic validation/test metrics | train-only `muX/sigmaX/muY/sigmaY` |
| Duplicate file entries | unintended sixfold weighting | manifest validator rejecting duplicates |
| Checkpoint names reused | model identity is ambiguous | model registry with path and SHA-256 |
| Source/checkpoint architecture mismatch | training cannot be reproduced | serialized architecture plus source commit |
| Training logs append | multiple runs mix in one file | unique run directory and run ID |
| No environment capture | toolbox/version behavior can differ | MATLAB/toolbox/GPU/driver metadata |
| No independent test suite | correctness regressions go unnoticed | group-held-out benchmark runner |

## Safe experiment design

The minimum defensible comparison is a leave-flight-out or predefined held-out-flight protocol:

1. Assign every source row a stable group key: constellation, trial, trajectory/manual run, and raw filename.
2. Freeze disjoint train, validation, and final-test group lists before looking at final-test results.
3. Reject duplicate manifest entries unless an explicit weight field justifies them.
4. Generate samples independently per flight and never create a window across boundaries.
5. Fit normalization on training rows only; store it with the model.
6. Fix and record RNG seeds.
7. Train each architecture on exactly the same train/validation groups.
8. Choose checkpoints using validation metrics only.
9. Run final test once and report per-flight plus aggregate distributions.
10. Evaluate raw UWB, classical baseline, FNN/CNN, and downstream ESKF with the same timestamp mapping and metric implementation.

For stronger generalization evidence, hold out an entire constellation after hyperparameters are fixed. This asks whether the network generalizes to new anchor geometry, not merely new windows from familiar flights.

## Model documentation template

Every future checkpoint should have a machine-readable record containing:

- run ID, timestamp, Git commit, and dirty-tree flag;
- MATLAB and toolbox versions, device, and execution environment;
- generator schema version and feature 109 definition;
- ordered train/validation/test group manifests and their hashes;
- data-file hashes and row counts;
- RNG seed/state;
- architecture and parameter count;
- loss, optimizer, learning-rate schedule, epochs, batch size, early stopping;
- train-only normalization arrays;
- checkpoint path and SHA-256;
- per-flight TDoA and position metrics;
- inference mapping version, ESKF configuration, and metric version.

Without these fields, a model can be demonstrated but not independently reproduced.

## Recommended repair sequence

1. Preserve current checkpoints and spreadsheets as read-only historical artifacts.
2. Add tests for feature order, source/target row mapping, denormalization, and metric formulas.
3. Define one versioned sample schema and resolve feature 109.
4. Create validated group manifests with no evaluation overlap or duplicate paths.
5. Centralize train-only normalization and deterministic seeds.
6. Make each architecture a function with unique layer names and a configuration object.
7. Centralize inference so every model uses the same target-index mapping.
8. Register checkpoints by immutable run ID and hash.
9. Retrain a simple linear/FNN baseline first, then CNN variants one controlled change at a time.
10. Recompute both TDoA and downstream ESKF metrics with confidence intervals or across-run variability.

The first retraining target should be the small FNN, not the deepest CNN: it is cheaper to use for validating data boundaries, normalization, determinism, checkpoint provenance, and end-to-end metric integrity.

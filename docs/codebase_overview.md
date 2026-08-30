# Codebase overview

## Review scope and status

This document records the effective working tree inspected on 2026-08-30 at Git base `a70cd27`. That initially dirty research snapshot was categorized and committed as `6978811`; the tracked files were subsequently organized by responsibility. Historical findings below still describe the audited algorithms, while paths now follow `docs/file_organization.md`.

The review environment is Windows with MATLAB R2025b (25.2). The thesis prompt names MATLAB R2022b as the original environment, so numerical and API compatibility with R2022b remains to be verified. Deep Learning Toolbox and Optimization Toolbox are installed in the review environment. The ESKF also uses MATLAB's `quaternion` and `quat2rotm` APIs.

No MATLAB Project file, package namespace, Live Script, Simulink model, or automated test suite was found. The active implementation is still a collection of scripts sharing the base workspace, but named baseline configuration now exists under `config/` and reusable functions are separated under `src/`.

## What the current system actually predicts

The neural networks do **not** directly predict position or position error. They predict a scalar, ground-truth-derived TDoA distance difference for the next occurrence of an anchor pair. That scalar is then substituted for the measured TDoA value and passed to the ESKF.

The generated network row contains 111 columns:

| Columns | Shape | Meaning in current code |
| --- | ---: | --- |
| 1-102 | 17 x 6 | Seventeen linearly interpolated IMU samples: accelerometer xyz followed by gyroscope xyz |
| 103-108 | 2 x 3 | Positions of anchor A and anchor B |
| 109 | 1 | Measured TDoA at the start occurrence of the pair; its CSV name `uwb_tdoA_last_gt` is misleading because current generation code uses a measurement, not ground truth |
| 110 | 1 | Measured TDoA at the next occurrence of the same pair |
| 111 | 1 | Target: ideal TDoA distance difference at that next occurrence, calculated from spline-interpolated Vicon position and surveyed anchors |

Training uses columns 1-110 as `X` and column 111 as `Y`. FNN inputs are `N x 110`; CNN inputs are reshaped to `110 x 1 x 1 x N`; model output is one scalar in metres. The saved checkpoints include `muX`, `sigmaX`, `muY`, and `sigmaY`.

## Repository structure

The inventory below explains the role of each important area rather than reproducing the full tree.

| Path | Observed contents | Role and status |
| --- | --- | --- |
| `csv-data/` | 80 CSV files, about 2.17 GB | Raw multi-sensor flight CSVs plus one generated `_NN.csv` at the directory root. The raw files contain sparse columns for TDoA, accelerometer, gyro, ToF, optical flow, barometer, and Vicon pose. Ignored by Git. |
| `survey-results/` | Four processed survey TXT files, four NPZ files, four constellation plots, and raw survey text | Eight anchor positions and quaternions per constellation. The processing path that produced the processed survey files is not present. |
| `export-data-set/` | 38 generated `_NN.csv` files plus `dataset_learning_all.mat`, about 8.4 GB | Older/full-rate generated network dataset. Untracked. |
| `export-data-set-r/` | 38 generated `_NN.csv` files, about 520 MB | Current reduced dataset produced after `downsamp` applies an 8x reduction. Used by the organized FNN/CNN1/CNN2 training scripts. Ignored by Git. |
| `src/` | Reusable MATLAB pipeline stages | Data extraction, preprocessing, TDoA generation, localization solvers, ESKF, evaluation, plotting, and utilities. |
| `scripts/` | Five responsibility folders | Preprocessing, training, evaluation, deployment, and visualization entry scripts. |
| `models/active/` | Five reviewed FNN/CNN checkpoints | Checkpoints referenced by the organized active workflows. |
| `models/legacy/` | Older CNN/LSTM checkpoints and training figures | Historical model family; same-numbered active and legacy models are not interchangeable. |
| `result/` | Large generated per-flight tree | Diaries and figures remain local and ignored. The four compact Excel summaries moved to `artifacts/baseline/source/`. Logs can contain multiple appended runs and failed/outlier runs. |
| `assets/diagrams/` and `tools/diagrams/` | Draw.io/exports and the Python generator | Thesis architecture assets and their generation tool. |
| `artifacts/baseline/` | Four source XLSX and three derived CSV files | Compact historical behavior-preservation evidence. |
| archives (`*.zip`, `*.rar`) | Repository, library, network, and dataset archives | Unversioned snapshots with unclear provenance. They were inventoried but not extracted because live equivalents already exist. |
| `ieee.m` | 577-line IEEE 802.15.4a channel simulation script | Standalone channel-model experiment; no reference from the localization pipeline was found. |

The tracked MATLAB implementation is split between workflow entry scripts in `scripts/`, named configuration in `config/`, and reusable functions/classes in `src/`. Generated results still dominate the local file count: 1,170 FIG files and 98 TXT logs were observed during the initial inventory.

## Dataset organization found on disk

There are 79 raw flight CSVs under the four constellation subdirectories:

| Constellation | Raw files | Organization found |
| --- | ---: | --- |
| const1 | 12 | Trials 1-6, each with `tdoa2` and `tdoa3` |
| const2 | 12 | Trials 1-6, each with `tdoa2` and `tdoa3` |
| const3 | 16 | Trials 1-6 with `tdoa2` and `tdoa3`, plus four manual files in trial 7 |
| const4 | 39 | Trials 1-6 x trajectories 1-3 x `tdoa2`/`tdoa3`, plus three `tdoa2` manual files in trial 7 |

The generated-data runner selects 38 unique `tdoa2` files: const1 trials 1-6, const2 trials 1-6, const3 trials 1-6 plus manual 1-2, and selected const4 files. It excludes const4 trial 5. Its 44-entry list repeats `const4-trial1-tdoa2-traj1` six times and repeatedly overwrites the same output file.

The 21-flight result set is explicitly listed in `inference.m`: const4 trials 1-6 for trajectories 1-3 (18 flights), followed by const4 trial-7 manual flights 1-3.

### Representative measured rates

For `const4-trial1-tdoa2-traj1.csv`:

| Stream | Samples | Median raw rate | Rate after current 8x downsampling |
| --- | ---: | ---: | ---: |
| Accelerometer | 127,675 | 1009.1 Hz | about 126.1 Hz |
| Gyroscope | 127,675 | 1009.1 Hz | about 126.1 Hz |
| Vicon pose | 25,363 | 201.9 Hz | not downsampled by the active loader |
| Each TDoA ring pair | about 6,865-7,593 | about 60.1 Hz | about 7.52 Hz |

This supports, for the current downsampled configuration, the observed choice of roughly 17 IMU samples between successive measurements of the same anchor pair. The code enforces exactly 17 samples by linear interpolation; it does not preserve a variable-length native sequence.

The representative reduced generated file has 7,304 rows and 111 columns. It contains eight rows with at least one non-finite value and one all-zero row. Training removes non-finite rows but does not remove the all-zero row.

## Main execution paths

### Dataset generation

`dataset_generator_runner.m` -> sets `csv_file`, `anchors`, and `export_csv_file` in the base workspace -> `data_extractor.m` compatibility wrapper -> `load_experiment_dataset` -> `synchronize_sensor_data` -> `preprocess_sensor_data` -> `dataset_generator.m` -> constructs 17-sample features -> `writetable` to `export-data-set-r/*.csv`

Important behavior:

- Each sensor stream is extracted independently from the sparse raw table.
- Gyro is linearly interpolated to accelerometer timestamps.
- Accelerometer/gyro and each of eight ring-pair TDoA streams are downsampled by 8.
- Vicon xyz is spline-interpolated to UWB timestamps.
- Ideal TDoA is computed as `distance(tag, B) - distance(tag, A)` in metres.
- The feature window spans one occurrence of a pair to the next occurrence of that pair and includes both endpoint TDoA measurements.

### FNN training

`train_tdoa_net1.m` -> reads 43 listed generated CSV inputs (38 unique; one flight repeated six times) -> concatenates rows -> selects 110 inputs and one target -> applies `zscore` to the complete dataset -> randomly splits individual rows 70/15/15 -> trains 128-ReLU-64-ReLU-1 regression network -> saves `trained_tdoa_net_fcc1.mat`

`train_tdoa_net.m` is an older alternative. Its source architecture does not match its current `trained_tdoa_net_5.mat`, and its active options refer to undefined `XVal`/`YVal` variables.

### CNN training

- `train_tdoa_cnn_net1.m` -> 110x1 image input -> conv(9,16) -> pool -> conv(5,32) -> FC32 -> scalar -> `trained_tdoa_net_cnn_1.mat`
- `train_tdoa_cnn_net2.m` -> four convolution blocks with kernels 20/10/5/3 and 8/16/32/64 channels -> FC64 -> FC32 -> scalar -> `trained_tdoa_net_cnn_2.mat`
- `train_tdoa_cnn_net3.m` -> deeper experimental network. The source repeats layer names and is not currently a valid reproducible training definition, although a saved CNN3 checkpoint exists.
- `train_tdoa_cnn_net.m` -> older CNN5 experiment using `export-data-set/` -> `models/legacy/trained_tdoa_net_cnn_5.mat`.

All active FNN/CNN training scripts normalize before splitting and use an uncontrolled `randperm` sample split.

### Raw ESKF evaluation

`fusion_eskf.m` -> hard-coded raw CSV and constellation -> `data_extractor.m` -> union IMU/UWB event timeline -> `ESKF.predict` for every event -> `ESKF.UWB_correct` on UWB events -> spline Vicon comparison -> axis and aggregate position metrics -> plots and diary under a hard-coded result directory

The nominal state is six-dimensional `[position; velocity]`. Attitude is stored separately as a scalar-first MATLAB quaternion. The covariance/error state is nine-dimensional `[position error; velocity error; small-angle attitude error]`.

### Baseline neural inference and position evaluation

`inference.m` -> selects one of 21 const4 flights by editing an index -> loads the configured active FNN through the shared TDoA model interface -> retains duplicated integration and feature-building logic -> predicts enhanced TDoA -> calculates TDoA metrics -> replaces `uwb(:,3)` -> runs the ESKF -> calculates position metrics -> writes figures and an appended diary

There is no loop that reproducibly evaluates every flight and every model. The Excel tables appear to have been assembled outside a single auditable runner.

### Alternative inference experiments

- `inference_timesequnce.m`: pair-wise autoregressive rollout over three history steps with an alpha filter (`alpha = 0.5`), then ESKF. Unlike `inference.m`, it maps a predicted target back to the target UWB row explicitly.
- `inference_tdoa.m`: single-step neural TDoA enhancement followed by sliding-window nonlinear least-squares position estimation without ESKF.
- Legacy tracked files `inference_lstm.m` and `train_tdoa_lstm_net.m`: the older LSTM workflow is preserved because its checkpoint remains under `models/legacy/`; it is not part of the active baseline.

### Quantization/export

`prepare_data_for_ptq.m` -> concatenates the same generated datasets -> applies saved CNN2 statistics -> random sample split into calibration/test -> saves `prepared_data_for_ptq.mat`

`ptq_tdoa_net.m` -> loads CNN2 and prepared tensors -> evaluates floating point -> attempts Deep Learning Toolbox INT8 PTQ -> saves a quantized checkpoint

`exportNetwork.m` -> loads CNN2 -> calls `exportONNXNetwork`; its declared input/output formats have not been validated against the 110x1x1 CNN input.

### Reporting and plots

`plot_rms_ma.m` and `plot_position_rms.m` read manually maintained Excel summaries and generate thesis plots. `src/visualization/plot_pos*.m` and `src/visualization/plot_traj.m` create per-run figures.

## ESKF summary from the implementation

| Item | Current implementation |
| --- | --- |
| Nominal translational state | 3-D position and 3-D velocity |
| Attitude | Separate quaternion, initialized `[1 0 0 0]` and used with MATLAB scalar-first convention |
| Error state/covariance | 9 states: position, velocity, small-angle attitude |
| IMU input units | Accelerometer stored in g and multiplied by 9.81; gyro stored in degrees/s and multiplied by pi/180 |
| World gravity | `[0, 0, -9.81]`, implying positive z upward |
| UWB measurement | TDoA range difference in metres, predicted as `d_B - d_A` |
| Lever arm | `[-0.01245, 0.00127, 0.0908]` metres, frame not explicitly documented |
| Measurement variance | `0.05 m^2` (`std_uwb_tdoa = sqrt(0.05)`) |
| Innovation gate | Scalar normalized innovation magnitude less than 5 |
| Current process-noise constants | acceleration 0.1 and gyro 0.01; both differ from Git HEAD |

Coordinate transformation direction, exact survey/world frame definition, and IMU-to-body alignment are not documented in source and remain `UNKNOWN` pending the dedicated coordinate-frame and mathematical reviews.

## Saved models found

The `models/active/` checkpoints are the ones referenced by organized current scripts:

| File | Saved network | Input/output |
| --- | --- | --- |
| `trained_tdoa_net_fcc1.mat` | FNN 128-64-1 | 110 features -> scalar TDoA |
| `trained_tdoa_net_cnn_1.mat` | 2 convolution blocks -> FC32 -> 1 | 110x1x1 -> scalar TDoA |
| `trained_tdoa_net_cnn_2.mat` | 4 convolution blocks -> FC64-FC32-1 | 110x1x1 -> scalar TDoA |
| `trained_tdoa_net_cnn_3.mat` | 5 convolution blocks -> FC64-FC32-1 | 110x1x1 -> scalar TDoA |
| `trained_tdoa_net_5.mat` | Saved network is FNN 128-64-1 despite the older source file defining a larger tanh network | 110 features -> scalar TDoA |

The `models/legacy/` directory contains different CNN1/CNN2/CNN3/CNN5 models and an LSTM checkpoint. Same-numbered active and legacy checkpoints are not interchangeable.

## Reconciliation of the quoted baseline

The existing Excel artifacts contain two different metric families.

| Existing table | Raw | FNN | CNN1 | CNN2 | CNN1 wins |
| --- | ---: | ---: | ---: | ---: | ---: |
| Mean per-flight TDoA RMSE, `result_overall_tdoa_rms.xlsx` | 0.392157 | 0.293181 | 0.282990 | 0.291595 | 19/21 |
| Mean per-flight TDoA MAE, `result_overall_tdoa_ma.xlsx` | 0.228557 | 0.183414 | 0.169762 | 0.182300 | not counted here |
| Mean per-flight position RMSE after ESKF, `result_position_rms.xlsx` | 0.502481 | 0.335681 | 0.324914 | 0.329262 | 8/21 |

The thesis prompt's quoted 0.392/0.293/0.283/0.292 RMS values, 0.229/0.183/0.170/0.182 MAE values, and 19-of-21 statement match the **TDoA error tables exactly**. They do not match the position RMSE table. This must be resolved before naming any value “position error” in a reproducible baseline report.

These tables were inspected, not regenerated. The current code does not yet provide a single command that proves they can be reproduced from the raw flights and named checkpoints.

## Immediate documentation gaps

The following remain deliberately unresolved rather than guessed:

- authoritative train/validation/test flight split and whether the 21 flights are intended as a held-out set;
- exact coordinate-frame names, axes, origins, and transform provenance;
- which active or legacy checkpoints correspond to thesis labels FNN/CNN1/CNN2;
- MATLAB R2022b toolbox versions and original random seeds;
- whether the quoted baseline is intended to describe TDoA error or final position error;
- provenance of generated CSVs, Excel summaries, archives, and model files;
- which uncommitted changes produced the saved February 2026 results;
- whether trial 4, trial 5, or a different grouping was intended as a held-out condition.

Those questions are routed into the follow-up data-flow, coordinate-frame, leakage, mathematical, ESKF, neural-network, and baseline documents in `refactoring_plan.md`.

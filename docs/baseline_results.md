# Baseline Results

## Baseline status

The current repository can deterministically reconstruct the saved 21-flight summary artifacts through:

```matlab
config = load_experiment_config("baseline");
results = run_baseline_evaluation(config);
```

This is a **historical artifact baseline**, not a fresh inference run. It protects the numeric summaries organized under `artifacts/baseline/source/` while the code is refactored. A live baseline cannot yet be claimed reproducible because the original run configuration, training seeds, exact preprocessing version, and checkpoint selection record were not saved, and the primary inference script has a documented target-row alignment problem.

No model was retrained and no scientific algorithm was changed to create this baseline.

## Generated records

| File | Purpose |
|---|---|
| `artifacts/baseline/derived/baseline_results.csv` | Long-form flight/task/model/metric values, including explicit unavailable values |
| `artifacts/baseline/derived/baseline_summary.csv` | Flight, trial, trajectory, constellation, and overall aggregations |
| `artifacts/baseline/derived/baseline_unavailable_metrics.csv` | Metrics that cannot be reconstructed from saved artifacts and the reason |
| `artifacts/baseline/derived/baseline_results.mat` | Generated MATLAB structure containing metadata and all three tables; ignored by Git |

The entry point refuses to overwrite these records by default. To regenerate them intentionally:

```matlab
config = load_experiment_config("baseline");
config.evaluation.overwrite = true;
results = run_baseline_evaluation(config);
```

## Environment

| Field | Recorded value |
|---|---|
| Reconstruction date | 2026-08-30, Asia/Tehran workspace context |
| Operating platform | Windows, MATLAB `win64` environment |
| MATLAB used for reconstruction | R2025b, version 25.2 |
| Project-stated compatibility target | R2022b |
| Git branch | `main` |
| Git commit | `a70cd2700fd1cd3fb1acf180033c5aed4327352b` |
| Worktree | Dirty before review; pre-existing modifications and untracked research artifacts preserved |
| Random seed for reconstruction | Not applicable; spreadsheet import and aggregation are deterministic |
| Original training seeds | **UNKNOWN**; active scripts do not call `rng` |

Installed MATLAB products include Deep Learning Toolbox, Optimization Toolbox, Navigation Toolbox, Sensor Fusion and Tracking Toolbox, and Aerospace Toolbox. The reconstruction itself requires only MATLAB table/spreadsheet support; it does not invoke training or ESKF execution.

## Dataset represented by the baseline

The source spreadsheets contain 21 flights, all from constellation 4:

- trials 1–6, trajectories 1–3: 18 flights;
- trial 7, manual trajectories 1–3: 3 flights.

Each flight is reported for four observation/model conditions:

- `raw`: raw UWB TDoA, or ESKF driven by raw UWB for position metrics;
- `fnn`: FNN/FCC1-enhanced TDoA;
- `cnn1`: CNN1-enhanced TDoA;
- `cnn2`: CNN2-enhanced TDoA.

The raw CSVs and checkpoints are present, but the spreadsheets do not store a dataset manifest, input hashes, sample-level errors, or an immutable reference to the exact generator/filter source used to create them.

## Source artifacts

| Artifact | Imported meaning | Completeness |
|---|---|---|
| `artifacts/baseline/source/result_overall_tdoa_rms.xlsx` | Per-flight TDoA RMSE for raw/FNN/CNN1/CNN2 | 21x4 finite values |
| `artifacts/baseline/source/result_overall_tdoa_ma.xlsx` | Per-flight TDoA MAE for raw/FNN/CNN1/CNN2 | 21x4 finite values |
| `artifacts/baseline/source/result_position_rms.xlsx` | Per-flight position RMSE for ESKF using raw/FNN/CNN1/CNN2 observations | 21x4 finite values |
| `artifacts/baseline/source/result_position_ma.xlsx` | Intended per-flight position MAE | 21x4 values, all `NaN` |

The first model column in the TDoA-RMSE workbook is named `eskf`, while the corresponding data and logs describe raw TDoA. The reconstruction normalizes this label to `raw` and retains the source-artifact path on every row.

## Checkpoints present during review

| Model artifact | SHA-256 |
|---|---|
| `models/active/trained_tdoa_net_5.mat` | `CA2D796C4C85EA327DA141E297E8192A80D51571E64D5203A084A4C369797884` |
| `models/active/trained_tdoa_net_fcc1.mat` | `ACFA6EEB66861189C093F020F7CEA0761FB6CFD86F433E4541871C5D83703405` |
| `models/active/trained_tdoa_net_cnn_1.mat` | `8AFB50E2F5DC75D657ED9A8EBCA8AE4C4DCB649E9BDC563D73B2314434CBB55B` |
| `models/active/trained_tdoa_net_cnn_2.mat` | `BC733D4ECB332FE180B11C11A8DB139D908F93665A208FBE7045D6BAD5FA774D` |
| `models/active/trained_tdoa_net_cnn_3.mat` | `0BC92B3410954CB066EEB0AFCFD340645A86F16B6D9EEFB62BEF3210FFA1F8A5` |

The spreadsheets do not identify checkpoint hashes. The table records candidates found in the repository, not a proven model-to-result lineage. CNN3 is not represented in the baseline spreadsheets.

## Preprocessing and evaluation configuration

The historical logs and current scripts indicate this intended path:

1. Extract raw IMU, UWB, ground truth, and anchor survey data.
2. Interpolate gyro to accelerometer timestamps and downsample streams.
3. Generate same-anchor-pair intervals with 17 interpolated IMU samples.
4. Normalize 110 features with statistics stored beside each checkpoint.
5. Predict an ideal/corrected scalar TDoA.
6. Replace raw TDoA with the prediction.
7. Run the 9-error-state ESKF and compare position against spline-interpolated Vicon ground truth.

Exact historical settings are not recoverable:

- the current working tree uses downsampling factor 8, while Git `HEAD` does not;
- ESKF process-noise constants have uncommitted changes;
- feature 109 changed between ideal and measured previous TDoA;
- the active inference source has hard-coded flight/model selection;
- its predicted target value is stored at a sequential row rather than the mapped target row;
- training normalization was fitted before row-level random splitting;
- 15 of the 21 evaluation flights appear in current training lists.

Accordingly, the baseline locks artifacts rather than asserting that the current scripts produced them correctly.

## Reconstructed overall metrics

Values are arithmetic means of 21 per-flight metrics. They are not pooled per-sample metrics.

### TDoA error

| Model | Mean flight RMSE (m) | SD (m) | Maximum (m) | P95 (m) | Mean flight MAE (m) | SD (m) | Maximum (m) | P95 (m) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Raw | 0.392157 | 0.147530 | 0.657300 | 0.607800 | 0.228557 | 0.062740 | 0.331500 | 0.316500 |
| FNN | 0.293181 | 0.088261 | 0.446100 | 0.416800 | 0.183414 | 0.046502 | 0.271500 | 0.235600 |
| CNN1 | 0.282990 | 0.092486 | 0.439900 | 0.410500 | 0.169762 | 0.045456 | 0.247600 | 0.218500 |
| CNN2 | 0.291595 | 0.096152 | 0.451100 | 0.428200 | 0.182300 | 0.050019 | 0.276600 | 0.244000 |

CNN1 has the lowest TDoA RMSE in 19 of 21 flights; FNN and CNN2 each lead one flight.

### Position error after ESKF

| Observation condition | Mean flight RMSE (m) | SD (m) | Maximum (m) | P95 (m) |
|---|---:|---:|---:|---:|
| Raw | 0.502481 | 0.166782 | 0.880500 | 0.743700 |
| FNN | 0.335681 | 0.126808 | 0.542600 | 0.495200 |
| CNN1 | 0.324914 | 0.119566 | 0.541000 | 0.503200 |
| CNN2 | 0.329262 | 0.135062 | 0.552900 | 0.519400 |

CNN1 has the lowest position RMSE in 8 of 21 flights, FNN in 7, and CNN2 in 6. Position MAE cannot be reconstructed: its workbook is all `NaN`, and the script's `ma_all` formula counts x twice while omitting z.

## Comparison with the master-prompt reference

The master prompt describes approximately 0.392/0.293/0.283/0.292 m as “RMS position error” and 0.229/0.183/0.170/0.182 m as “MAE position error.” The saved artifacts reproduce those sequences as **TDoA RMSE and TDoA MAE**, respectively.

| Model | Prompt-labelled RMS position (m) | Reconstructed TDoA RMSE (m) | Saved position RMSE (m) | Position difference from prompt (m) |
|---|---:|---:|---:|---:|
| Raw | ~0.392 | 0.392157 | 0.502481 | +0.110481 using rounded prompt value |
| FNN | ~0.293 | 0.293181 | 0.335681 | +0.042681 using rounded prompt value |
| CNN1 | ~0.283 | 0.282990 | 0.324914 | +0.041914 using rounded prompt value |
| CNN2 | ~0.292 | 0.291595 | 0.329262 | +0.037262 using rounded prompt value |

The “CNN1 best in approximately 19 of 21 flights” statement also matches the TDoA-RMSE workbook. It does not describe position RMSE, where CNN1 leads 8 flights.

This is a labeling/provenance finding, not evidence that any algorithm should be tuned to match the prompt.

## Unavailable required metrics

The historical spreadsheets do not contain signed sample errors, so the following cannot be recovered without a live rerun:

- signed mean error;
- sample-level standard deviation;
- maximum absolute sample error;
- sample-level percentiles;
- valid position MAE.

`baseline_summary.csv` does provide standard deviation, extrema, and percentiles **across the 21 flight-level RMSE/MAE values**. Its column names explicitly say `FlightMetric` to prevent those numbers from being mistaken for sample-error distributions.

## Baseline acceptance and next gate

The historical baseline is accepted as a behavior-preservation fixture if:

- exactly 21 canonical flight labels are present in every source workbook;
- all TDoA RMSE, TDoA MAE, and position RMSE cells are finite;
- the output contains 336 long-form rows;
- the four overall TDoA sequences reproduce the prompt values to spreadsheet rounding;
- unavailable position MAE remains explicitly unavailable, not imputed.

Before claiming a new scientific baseline, the project must add a noninteractive live evaluator, fix or deliberately preserve the target-row mapping under test, freeze a leakage-safe flight manifest, and record sample-level error vectors. That work begins after the review/refactoring boundary defined in item 16.

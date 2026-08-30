# Behavior-preserving refactoring plan

## Objective

Turn the current script collection into an auditable localization experiment pipeline without silently changing the thesis result. Structural refactoring and scientific corrections are separate work streams. A stage is complete only when its tests and numerical comparison are recorded.

## Non-negotiable guardrails

1. Preserve the current dirty working tree and all user-owned research artifacts. Do not reset, delete, rename, or overwrite them as cleanup.
2. Treat current behavior as `legacy`, including behavior that appears wrong, until a regression fixture records it.
3. Mark every scientific correction `BEHAVIOR CHANGE` and compare legacy and corrected results side by side.
4. Never update a baseline file in place. Each run gets an immutable directory and manifest.
5. Use saved checkpoints before retraining. Training is a later, explicitly configured experiment.
6. Split by flight/group before fitting normalization for new leakage-safe experiments; retain the old sample split only as a named legacy mode.
7. Stop a stage when an unexplained numerical difference appears.

## Proposed target shape

This is a direction, not a request for a bulk move:

```text
configs/
    baseline_legacy.m
    baseline_grouped.m
src/
    data/
    preprocessing/
    features/
    models/
    eskf/
    evaluation/
    visualization/
tests/
    unit/
    regression/
experiments/
results/
    <immutable-run-id>/
docs/
```

MATLAB functions should remain mathematically inspectable. No large object-oriented framework is proposed; a config struct plus small functions is sufficient.

## Stage plan

Each row answers what changes, why, whether behavior changes, how equivalence is checked, and likely files affected.

| Stage | Change | Why | Intentional numerical change? | Equivalence/validation | Expected files |
| --- | --- | --- | --- | --- | --- |
| 0. Complete discovery | Add dependency, data-flow, coordinate-frame, dataset, leakage, math, ESKF, neural-model, and baseline provenance documents | Resolve unknowns before moving equations | No | Cross-check every claim against source/data/model metadata; mark unresolved facts `UNKNOWN` | `docs/*.md` only |
| 1. Freeze provenance | Record Git commit/diff identity, MATLAB/toolbox versions, file manifests, checkpoint/result SHA-256, and the exact 21-flight list | Existing artifacts are not tied to source/config | No | A manifest can identify every input used by a run; no artifact is modified | `configs/`, `docs/baseline_results.md`, small manifest utilities |
| 2. Define metric contracts | Add pure TDoA and position metric functions with explicit names/units; include a `legacy_position_mae_xxy` diagnostic but do not call it the corrected metric | Current metric names and formulas are ambiguous | No for legacy outputs; corrected MAE is a separate behavior-change result | Synthetic known-value unit tests; reproduce existing Excel arithmetic exactly | `src/evaluation/`, `tests/unit/test_metrics.m` |
| 3. Build a read-only baseline summarizer | Import existing 21-flight spreadsheets/log references into a long-form table with model/domain/metric/flight fields | Establish a machine-readable historical baseline before rerunning expensive pipelines | No | Means reproduce 0.392157/0.293181/0.282990/0.291595 and corresponding MAE values; position table remains distinct | `src/evaluation/`, `results/historical-baseline/`, docs |
| 4. Extract configuration | Move existing paths, flight lists, checkpoint paths, 17-sample count, downsampling factor, ESKF initialization/noise, gate, and output settings into config without changing values | Remove source edits as the experiment interface | No | One representative legacy flight matches captured outputs within tolerance; config dump lists every value | `configs/`, `src/utilities/`, thin edits to entry scripts |
| 5. Establish dataset loader | Convert `data_extractor.m` logic into `load_experiment_dataset(config)` returning raw/synchronized data and metadata; keep a legacy wrapper | Remove base-workspace dependency and make units/shapes explicit | No | Compare every returned array against the script workspace on a representative flight; assert row masks and timestamps | `src/data/`, `tests/unit/test_dataset_loader.m`, legacy wrapper |
| 6. Isolate preprocessing | Extract gyro interpolation, time-origin handling, downsampling, pair selection, Vicon interpolation, and ideal-TDoA generation | Training and inference must share exactly one implementation | No in `legacy` mode | Array-level regression on representative flight; synthetic interpolation/downsample tests | `src/preprocessing/`, `src/uwb/`, `src/imu/`, tests |
| 7. Isolate event integration | Implement an explicit event table carrying source timestamp, effective update timestamp, sensor type, and source row | Current `t(k-1)`/row-`k` convention is hidden | No initially: provide `legacy_left_sample_to_next_row` mode | Synthetic timeline test and exact legacy array comparison | `src/preprocessing/integrate_sensor_events.m`, tests |
| 8. Unify feature generation | Implement `build_tdoa_features(processed, config)` returning `X`, `Y`, source flight, start row, target row, pair, and timestamps | Feature ordering/alignment is duplicated and untraceable | No in legacy mode | Reproduce all 111 generated columns for a small fixture; assert 17x6 + anchors + two TDoAs + target ordering | `src/features/`, `tests/unit/test_feature_builder.m`, regression fixture |
| 9. Unify model loading/inference | Add a checkpoint registry and `load_tdoa_model`/`predict_tdoa` interface for FNN/CNN1/CNN2 | Same model names currently resolve to different files/shapes | No | Saved checkpoint predictions match direct `predict` on frozen feature tensors | `configs/models/`, `src/models/`, model smoke tests |
| 10. Wrap legacy ESKF | Move orchestration into a pure runner while leaving `ESKF.m` equations unchanged | Enable repeatable raw/enhanced comparisons | No | State, covariance, quaternion, accepted updates, and per-flight metrics match current class outputs | `src/eskf/`, `tests/regression/`, thin legacy script |
| 11. Create experiment runner | Implement `results = run_baseline_evaluation(config)` over all 21 flights and named methods; save config, predictions, metrics, logs, and hashes | Replace manual editing and spreadsheets | No | Reproduce historical TDoA tables and document every position deviation; clean-session execution | `experiments/`, `src/evaluation/`, `results/<run-id>/` |
| 12. Add regression gate | Store a small representative fixture and expected legacy outputs with tolerances | Protect refactoring from scientific drift | No | `runtests('tests')` plus baseline comparison passes before each refactor merge | `tests/regression/`, `docs/refactoring_validation.md` |
| 13. Separate visualization | Convert repeated plotting into functions consuming result structs | Stop figures/logging from controlling computation | No | Plot data arrays match runner outputs; plotting can be disabled for batch runs | `src/visualization/`, plotting tests where practical |
| 14. Repository hygiene | Classify tracked source, source data, derived data, checkpoints, results, caches, and archives; update ignore rules only after provenance review | Current untracked/duplicate state is unsafe | No | Dry inventory reviewed before any move/removal; no research artifact deleted | `.gitignore`, docs, optional archive manifest |

## Explicit behavior-change experiments

These do not belong in a pure-refactor commit. Each requires a minimal failing demonstration, a test, a new config name, and a complete 21-flight comparison.

| Change ID | Hypothesis/fix | Required evidence before change | Comparison |
| --- | --- | --- | --- |
| BC-01 | Attach neural prediction to the actual next same-pair target row instead of sequential row `m` | Synthetic pair-alignment test and captured legacy mapping | Legacy versus corrected TDoA and position metrics per pair/flight |
| BC-02 | Replace x+y+x aggregate position MAE with documented Euclidean and/or axis metrics | Synthetic metric test and agreement on thesis definition | Old printed value versus corrected metric; never overwrite old logs |
| BC-03 | Use group-held-out splits and training-only normalization | Split manifest showing current overlap and leakage | Legacy random-epoch versus leave-flight/trajectory/constellation-out |
| BC-04 | Resolve event-time indexing (`t(k-1)` stored/corrected at `t(k)`) | Synthetic event test and written timing convention | State/prediction differences and full baseline rerun |
| BC-05 | Fix NLS `d_A-d_B` versus `d_B-d_A` convention | Known-position synthetic TDoA test | TDoA-only solver residual and position accuracy |
| BC-06 | Resolve ESKF rotation lag, quaternion normalization, covariance injection/reset, and covariance update form | Finite-difference Jacobian and stationary/known-motion tests | State/covariance diagnostics plus all-flight metrics |
| BC-07 | Decide whether feature 109 is measured previous TDoA or ideal previous TDoA | Artifact provenance and inference-availability analysis | Separate feature-set experiments; ground-truth input forbidden at deployment |
| BC-08 | Revisit downsampling and process-noise values | Reproduce current and Git-HEAD configurations from explicit config | Same checkpoints where valid, or separately retrained experiments |

## Baseline runner contract

The eventual public entry point should be conceptually:

```matlab
config = load_experiment_config("baseline_legacy");
results = run_baseline_evaluation(config);
```

Minimum config fields:

```text
experiment.name
experiment.seed
dataset.root
dataset.anchor_root
dataset.flight_manifest
split.strategy
preprocessing.downsample_factor
preprocessing.imu_window_samples
preprocessing.event_time_convention
features.definition
model.id
model.checkpoint
eskf.initial_state
eskf.initial_covariance
eskf.process_noise
eskf.measurement_noise
eskf.innovation_gate
evaluation.metric_definitions
output.root
```

Minimum per-run outputs:

```text
config.mat / config.json
environment.txt
input_manifest.csv
model_manifest.csv
metrics_long.csv
predictions/<flight>.mat
logs/run.txt
figures/
```

`metrics_long.csv` should contain one row per run/flight/model/domain/metric, avoiding separate manually edited spreadsheets for each metric.

## Test order

Tests should be added in this order because later refactors depend on earlier contracts:

1. metric definitions;
2. TDoA pair/sign convention;
3. feature flattening and target-row alignment;
4. sensor row masks, time origin, interpolation, and downsampling;
5. training-only normalization reuse;
6. split-manifest disjointness and window boundary checks;
7. model load/predict shape checks;
8. ESKF stationary, constant-velocity, quaternion, covariance, and Jacobian checks;
9. representative numerical regression;
10. full 21-flight baseline.

## Numerical comparison policy

- Store raw predictions/states, not only rounded metrics.
- Compare sample counts and source IDs before comparing values.
- Use documented absolute/relative tolerances appropriate to each stage.
- Treat a changed sample set, order, or target mapping as a behavior change even if the aggregate metric is close.
- Investigate every unexplained aggregate change; do not accept “small” drift by default.
- Report legacy TDoA metrics separately from final position metrics.

## Incremental commit sequence

Suggested reviewable commits after the remaining discovery documents are complete:

1. `docs: document thesis pipeline and scientific risks`
2. `test: define localization metric contracts`
3. `chore: record baseline artifact manifests`
4. `refactor: introduce explicit legacy experiment config`
5. `refactor: extract dataset loader in legacy mode`
6. `test: add synchronization and feature regression fixtures`
7. `refactor: centralize feature generation in legacy mode`
8. `refactor: register saved model inference interfaces`
9. `refactor: wrap legacy ESKF evaluation`
10. `feat: add reproducible 21-flight baseline runner`

Behavior changes such as corrected target alignment, grouped splitting, metric correction, or ESKF mathematics must each use a separate commit and result directory.

## Stop gates

Pause refactoring and investigate if any of the following occurs:

- sample count or flight membership changes unexpectedly;
- feature tensor ordering or normalization differs;
- a saved model prediction differs on the same frozen tensor;
- an ESKF state/covariance differs before an intentional ESKF change;
- legacy table means fail to match the recorded Excel arithmetic;
- a data or model hash changes;
- a new split includes a train/evaluation overlap;
- MATLAB R2022b and R2025b produce unexplained differences.

## Next work

The next safe phase is documentation and validation, not an algorithm rewrite: create `dependency_map.md`, `data_flow.md`, `coordinate_frames.md`, `dataset_structure.md`, `data_leakage_review.md`, `math_implementation_review.md`, `eskf_review.md`, and `neural_network_review.md`; then freeze the historical baseline and add metric/alignment tests. Only after those gates should configuration and loader extraction begin.

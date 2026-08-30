# Experiment configuration

## Scope

The first configuration refactor covers the deterministic historical baseline.
It extracts values that already existed in `run_baseline_evaluation.m`; it does
not select new parameters or change scientific behavior.

Load the named configuration after initializing the project path:

```matlab
setup_project;
config = load_experiment_config("baseline");
config.evaluation.writeOutput = false;
results = run_baseline_evaluation(config);
```

`load_experiment_config` recursively merges an optional override structure, so
callers can alter a single run-control setting without copying the full config.
The former flat baseline fields (`sourceDir`, `outputDir`, `writeOutput`, and
`overwrite`) remain accepted for backward compatibility.

## Baseline schema

| Field | Existing value moved from code | Purpose |
|---|---|---|
| `name` | `baseline` | Named configuration identifier |
| `behaviorMode` | `historical_artifact_reconstruction` | Distinguishes artifact reconstruction from live inference |
| `paths.repositoryRoot` | repository containing `config/` | Root for resolved project paths |
| `paths.sourceDir` | `artifacts/baseline/source/` | Historical XLSX inputs |
| `paths.outputDir` | `artifacts/baseline/derived/` | Machine-readable outputs |
| `dataset.constellation` | `const4` | Constellation encoded by all 21 source rows |
| `dataset.expectedFlightCount` | `21` | Completeness assertion |
| `models.names` | raw, FNN, CNN1, CNN2 | Workbook column order |
| `evaluation.artifacts` | four existing XLSX names/task/metric mappings | Artifact import contract |
| `evaluation.writeOutput` | `true` | Existing default output behavior |
| `evaluation.overwrite` | `false` | Existing output protection behavior |
| `evaluation.outputFiles` | three CSV files and one MAT file | Derived artifact names |

## Deferred hard-coded candidates

The review found many additional values in stateful training and inference
scripts: dataset lists, the 17-sample IMU window, downsampling, ESKF initial
state/noise, search windows, alpha-filter settings, split ratios, network
hyperparameters, and checkpoint paths. They are deliberately not all moved in
this step. Those scripts do not yet have representative array-level regression
fixtures, and a bulk extraction would make accidental behavior changes hard to
detect. Each group should move when its pipeline stage receives a test, as
scheduled in `docs/refactoring_plan.md`.

## Legacy preprocessing configuration

Section 20 adds `load_experiment_config("legacy_pipeline")`. It records the
existing gyro interpolation/extrapolation, common time-origin rule, Vicon start
rule, factor-8 downsampling, ordered ring-pair list, spline interpolation, and
ideal-TDoA generation switch. Per-flight CSV and anchor paths remain required
overrides; the configuration does not silently choose a dataset.

## Behavior guarantee

This step changes parameter ownership, not values. Acceptance requires the
baseline to retain 21 flights, 336 long-form rows, 576 summary rows, and the
same headline metrics. Both the named nested configuration and the former flat
override interface are validated.

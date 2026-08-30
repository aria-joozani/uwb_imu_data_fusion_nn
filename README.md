# UWB–IMU Data Fusion with Neural TDoA Enhancement

MATLAB research code for indoor positioning using UWB TDoA, IMU propagation,
neural TDoA enhancement, and an error-state Kalman filter.

## Quick start

Start MATLAB in the repository root and initialize the categorized code paths:

```matlab
setup_project;
config = load_experiment_config("baseline");
config.evaluation.writeOutput = false;
results = run_baseline_evaluation(config);
```

The historical baseline reads compact evidence from `artifacts/baseline/source/`.
Raw datasets remain local under `csv-data/`, `export-data-set*/`, and
`survey-results/`.

## Layout

| Directory | Contents |
|---|---|
| `scripts/preprocessing/` | extraction, synchronization, and dataset generation scripts |
| `scripts/training/` | FNN, CNN, and legacy LSTM training scripts |
| `scripts/evaluation/` | raw/NN/ESKF evaluation and the baseline entry point |
| `scripts/deployment/` | PTQ preparation, quantization, and ONNX export |
| `scripts/visualization/` | standalone thesis plotting scripts |
| `config/` | named, behavior-preserving experiment configurations and legacy metadata |
| `src/` | reusable data, preprocessing, UWB, localization, ESKF, evaluation, and plotting stages |
| `models/active/` | checkpoints used by the reviewed active workflows |
| `models/legacy/` | older checkpoints and training artifacts |
| `artifacts/baseline/` | compact historical source and derived baseline records |
| `assets/diagrams/` | editable Draw.io sources and exported diagrams |
| `docs/` | code, data, mathematics, leakage, and refactoring reviews |
| `local-artifacts/` | ignored logs, plots, archives, and large intermediates |

See `docs/file_organization.md` for the full move map and execution rules.

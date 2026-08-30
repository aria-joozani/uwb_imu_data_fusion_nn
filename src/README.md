# Reusable MATLAB pipeline stages

The `src/` tree contains reusable functions and classes grouped by scientific
responsibility. Entry scripts remain under `scripts/`; configuration remains
under `config/`.

| Stage | Responsibility | Current contents |
|---|---|---|
| `data/` | Load flights/surveys and extract sensor fields | `load_experiment_dataset`, `extract_*` functions |
| `preprocessing/` | Shared synchronization and sensor preprocessing | `synchronize_sensor_data`, `preprocess_sensor_data`, legacy helpers |
| `uwb/` | Generate ideal TDoA sequences | ground-truth TDoA generation/simulation |
| `localization/` | Estimate position from TDoA | 2-D/3-D NLS solvers and residual |
| `eskf/` | Inertial/UWB state estimation | `ESKF` class |
| `evaluation/` | Compare scientific outputs | simulated/measured TDoA comparison |
| `visualization/` | Reusable per-run scientific plots | position, error, and trajectory plots |
| `utilities/` | Small domain-independent helpers | NaN removal and timestamp membership |

Run `setup_project` from the repository root to add these explicit stage
folders to the MATLAB path. `setup_project` intentionally avoids `genpath`, so
archives, artifacts, models, and future private/test folders cannot silently
become runtime dependencies.

This is a structural separation only. Function names, signatures, equations,
constants, and numerical operations were not changed during the move.

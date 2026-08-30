# Pipeline-stage separation

## Outcome

Section 18 separates reusable MATLAB code by its actual responsibility while
leaving stateful experiment entry points under `scripts/`. The change moves
files and changes path initialization only; it does not modify algorithms,
function signatures, constants, model files, datasets, or baseline values.

```text
config/                 named experiment configuration
scripts/                stateful workflow entry points
  preprocessing/
  training/
  evaluation/
  deployment/
  visualization/
src/                    reusable pipeline implementation
  data/
  preprocessing/
  uwb/
  localization/
  eskf/
  models/
  evaluation/
  visualization/
  utilities/
```

## Stage contracts currently present

| Stage | Inputs | Outputs | Current boundary |
|---|---|---|---|
| Data | Imported sparse flight table | Per-sensor numeric arrays | `extract_*` functions |
| Preprocessing | Loaded dataset and legacy configuration | Synchronized and processed structures | `synchronize_sensor_data`, `preprocess_sensor_data` |
| UWB | Ground-truth positions and surveyed anchors | Ideal TDoA range differences | `generate_tdoa_from_gt`, `simulate_tdoa_sequence_from_gt` |
| Localization | Anchor pairs, TDoA values, initial position | NLS position and residuals | `solve_tdoa_nls_2d/3d`, `tdoa_residuals_3d` |
| ESKF | Initial state/covariance and event updates | State/covariance histories | `ESKF` |
| Models | Raw `N x 110` features and configured checkpoint | Corrected scalar TDoA in metres | `load_tdoa_correction_model`, `predict_tdoa_correction` |
| Evaluation | Simulated and measured TDoA | RMSE, mean error, error vector | `compare_tdoa_sim_vs_meas` |
| Visualization | Estimated/reference states and uncertainties | MATLAB figures | `plot_pos`, `plot_pos_err`, `plot_traj` |
| Utilities | Arrays or timestamp vectors | Cleaned arrays or lookup result | `deleteNAN`, `isin` |

## Dependency direction

The observed reusable dependency direction is intentionally simple:

```text
scripts
  -> data -> utilities
  -> preprocessing
  -> uwb
  -> localization
  -> eskf
  -> models
  -> evaluation
  -> visualization
```

`src/uwb/simulate_tdoa_sequence_from_gt.m` calls the TDoA generator in the
same stage. `src/localization/solve_tdoa_nls_*.m` calls the shared localization
residual. `src/preprocessing/sync_pos.m` calls the interpolation helper. No
package namespaces or new dependency framework were introduced.

## Deliberately deferred stages

There is no shared `features/` implementation folder yet. Model checkpoint
loading, normalization, tensor reshaping, and FNN/CNN prediction are now shared
under `src/models/`; feature-window construction remains inside legacy scripts.
Creating an empty feature folder would imply an interface that does not exist.

The stateful scripts also remain in `scripts/`. Moving their contents into
`src/` before converting them to functions would only disguise their hidden
base-workspace dependencies.

## MATLAB path contract

`setup_project.m` explicitly adds the nine `src/` stage folders, the named
configuration folder, and the five script-category folders. It does not use
`genpath` and does not add models, datasets, baseline artifacts, archives, or
ignored local outputs.

## Validation contract

The stage move is accepted when:

- every moved function resolves from its new `src/` location;
- no tracked MATLAB source still resolves from the former `library/` folder;
- MATLAB Code Analyzer findings do not increase because of the move;
- the baseline remains 21 flights, 336 long-form rows, and 576 summaries;
- headline metrics remain numerically identical.

Validation on 2026-08-30 passed all of these conditions. MATLAB resolved all
23 moved reusable files from their expected `src/` locations. Code Analyzer
scanned 50 tracked MATLAB files and reported the same 22 documented legacy
findings as before the move. The reconstructed baseline retained 21 flights,
336 long-form rows, 576 summaries, and unchanged headline values.

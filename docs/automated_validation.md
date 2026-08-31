# Automated validation

## Entry point

Run the complete MATLAB test suite from the repository root:

```matlab
results = run_project_tests();
```

The runner initializes project paths, discovers function-based tests below
`tests/`, prints the result table, and raises an error if any test fails or is
incomplete. This makes a failed validation visible to MATLAB batch jobs and CI.

## Current coverage

| Test file | Contract protected |
|---|---|
| `test_metrics.m` | TDoA residual direction, scalar RMSE/MAE, Euclidean position metrics, preserved legacy x+x+y diagnostic, and size validation |
| `test_coordinate_transform.m` | Active ESKF scalar-first quaternion rotation direction and stationary identity-attitude gravity cancellation |
| `test_dataset_loader.m` | Raw CSV and anchor parsing, returned structure shapes, optional raw-table retention, and missing-file diagnostics |
| `test_preprocessing.m` | Legacy time origin, IMU synchronization, downsampling, pair selection, Vicon interpolation, ideal-TDoA sign, and unsupported-mode rejection |
| `test_synchronization.m` | Linear gyroscope interpolation/extrapolation, common time origin, and strict ground-truth start behavior |
| `test_tdoa_solver.m` | Known-position 2-D/3-D NLS recovery under the native solver convention and characterization of its sign incompatibility with generated measurements |
| `test_model_interface.m` | Shared FNN prediction equivalence, checkpoint normalization reuse, feature-width validation, and unknown-model rejection |
| `test_baseline_regression.m` | Historical 21-flight record counts and published aggregate TDoA/position values from compact baseline artifacts |
| `regression/test_pipeline_regression.m` | Frozen sample-level loader, synchronization, downsampling, ordering, ground-truth interpolation, ideal-TDoA, and metadata outputs |

The loader and preprocessing tests generate temporary synthetic inputs and do
not depend on the multi-gigabyte local datasets. The model test requires Deep
Learning Toolbox and the tracked active FNN checkpoint. The baseline regression
uses the tracked compact evidence under `artifacts/baseline/`.

## Section 23 validation record

On 2026-09-01, MATLAB R2025b discovered and passed all 23 tests with no failed
or incomplete results. MATLAB Code Analyzer reported zero findings across the
runner and Section 23-25 test files. The model smoke test may emit a MATLAB GPU
support warning on older devices; this is informational and does not change the
test result.

## Deliberate limits

This suite protects the contracts already extracted during the behavior-
preserving refactor. It does not claim complete scientific verification. The
following remain candidates for the dedicated high-priority test phase:

- feature-window construction, trajectory-boundary enforcement, and target-row alignment;
- event integration timing and full ESKF state/covariance regression;
- the unavailable survey-to-Vicon transformation and finite-difference Jacobians;
- correction of the characterized nonlinear TDoA solver sign mismatch;
- full raw-data regeneration of all 21 historical flight results;
- CNN1/CNN2 prediction fixtures and MATLAB R2022b compatibility.

These exclusions keep Section 23 from silently changing known scientific
behavior while still providing a repeatable test gate for subsequent work.

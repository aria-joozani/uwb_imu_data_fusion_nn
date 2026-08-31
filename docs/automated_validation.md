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
| `test_dataset_loader.m` | Raw CSV and anchor parsing, returned structure shapes, optional raw-table retention, and missing-file diagnostics |
| `test_preprocessing.m` | Legacy time origin, IMU synchronization, downsampling, pair selection, Vicon interpolation, ideal-TDoA sign, and unsupported-mode rejection |
| `test_model_interface.m` | Shared FNN prediction equivalence, feature-width validation, and unknown-model rejection |
| `test_baseline_regression.m` | Historical 21-flight record counts and published aggregate TDoA/position values from compact baseline artifacts |

The loader and preprocessing tests generate temporary synthetic inputs and do
not depend on the multi-gigabyte local datasets. The model test requires Deep
Learning Toolbox and the tracked active FNN checkpoint. The baseline regression
uses the tracked compact evidence under `artifacts/baseline/`.

## Section 23 validation record

On 2026-08-31, MATLAB R2025b discovered and passed all 12 tests with no failed
or incomplete results. MATLAB Code Analyzer reported zero findings across the
runner and test files after cleanup. The model smoke test may emit a MATLAB GPU
support warning on older devices; this is informational and does not change the
test result.

## Deliberate limits

This suite protects the contracts already extracted during the behavior-
preserving refactor. It does not claim complete scientific verification. The
following remain candidates for the dedicated high-priority test phase:

- feature-window construction and target-row alignment;
- event integration timing and full ESKF state/covariance regression;
- coordinate-frame transformations and finite-difference Jacobians;
- nonlinear TDoA solver sign and known-position recovery;
- full raw-data regeneration of all 21 historical flight results;
- CNN1/CNN2 prediction fixtures and MATLAB R2022b compatibility.

These exclusions keep Section 23 from silently changing known scientific
behavior while still providing a repeatable test gate for subsequent work.

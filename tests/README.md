# MATLAB automated validation

Run the complete suite from the repository root:

```matlab
results = run_project_tests();
```

The suite uses MATLAB's Unit Testing Framework and currently covers:

- known-value scalar TDoA metrics;
- known-value axis and Euclidean position metrics;
- explicit preservation of the historical `x+y+x` diagnostic;
- raw CSV and anchor-survey loading with temporary synthetic files;
- gyro interpolation/extrapolation, time-origin shifting, pair filtering,
  downsampling, Vicon interpolation, and ideal-TDoA generation;
- active ESKF scalar-first quaternion direction and stationary-frame behavior;
- synthetic 2-D/3-D NLS recovery and explicit characterization of the known
  generator-versus-solver TDoA sign mismatch;
- active FNN checkpoint loading, normalization reuse, and prediction equivalence;
- frozen sample-level regression through loading, synchronization, and
  preprocessing using tracked text fixtures under `regression/fixtures/`;
- deterministic reconstruction of the 21-flight historical baseline.

Synthetic tests do not write into repository datasets. Temporary loader files
are managed by `TemporaryFolderFixture`. The model and baseline regression
tests use tracked checkpoints and compact baseline artifacts.

See `docs/high_priority_test_results.md` for the Section 24 test matrix and
the sequence/frame gaps that cannot yet be verified safely.
See `docs/refactoring_validation.md` for the Section 25 numerical comparison,
tolerances, fixture provenance, and reference-update policy.

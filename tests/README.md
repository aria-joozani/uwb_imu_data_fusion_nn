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
- gyro synchronization, time-origin shifting, pair filtering, downsampling,
  Vicon interpolation, and ideal-TDoA generation on synthetic streams;
- active FNN checkpoint loading and prediction equivalence;
- deterministic reconstruction of the 21-flight historical baseline.

Synthetic tests do not write into repository datasets. Temporary loader files
are managed by `TemporaryFolderFixture`. The model and baseline regression
tests use tracked checkpoints and compact baseline artifacts.

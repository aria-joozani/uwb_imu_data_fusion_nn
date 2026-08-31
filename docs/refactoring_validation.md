# Refactoring validation

## Purpose

Section 25 adds a small numerical regression gate for the extracted data
pipeline. It complements, rather than replaces, the compact 21-flight baseline
regression. The fixture is synthetic so it can remain tracked, fast, and
independent of the multi-gigabyte local datasets.

Run all validation from the repository root:

```matlab
results = run_project_tests();
```

## Frozen representative fixture

The fixture under `tests/regression/fixtures/` contains:

| File | Purpose |
|---|---|
| `representative_flight.csv` | Twelve raw table rows with staggered IMU timestamps, two alternating UWB pairs, ground-truth pose, and trailing missing UWB rows |
| `representative_anchors.txt` | Eight non-coplanar synthetic anchor positions and identity survey quaternions |
| `expected_processed_imu.csv` | Frozen downsampled IMU timestamps and six-axis samples |
| `expected_processed_uwb.csv` | Frozen ordered UWB rows, spline-interpolated ground truth, and generated ideal TDoA |

The data are intentionally artificial and contain no thesis-flight
measurements. Values were chosen to discriminate among interpolation,
extrapolation, time-origin, per-pair downsampling, sorting, and TDoA-sign
behaviors while remaining manually inspectable.

## Configuration under test

`test_pipeline_regression.m` starts from `legacy_pipeline_config` and changes
only fixture-specific inputs:

```text
dataset.csvFile                 representative_flight.csv
dataset.anchorFile              representative_anchors.txt
dataset.includeRawTable         false
preprocessing.downsampleFactor  2
preprocessing.anchorPairs       [7 0; 0 1]
```

All synchronization and interpolation modes remain the named legacy modes.
The smaller downsampling factor produces enough retained rows to distinguish
pair-specific selection and global timestamp ordering.

## Frozen contracts

The regression test checks full arrays, dimensions, ordering, and metadata:

- common time origin is exactly `9 s`;
- synchronized/downsampled IMU output is `6 x 7` including timestamp;
- UWB/ground-truth/ideal-TDoA output is `5 x 8`;
- sample counts are IMU `6`, UWB `5`, and retained ground truth `11`;
- retained anchor-pair configuration is `[7 0; 0 1]`;
- UWB rows remain sorted by shifted timestamp;
- every stored numeric sample matches within absolute tolerance `1e-12`.

The expected CSVs are the fixed `before_change` reference for subsequent
pipeline work. On 2026-09-01 the current loader, synchronization, and
preprocessing path matched them without unexplained numerical drift. Because
the extraction commits predate creation of this small fixture, these CSVs are
not misrepresented as output from an independently archived pre-refactor
executable. The independently preserved before/after evidence remains the
historical artifact regression described below.

## Relationship to historical results

`test_baseline_regression.m` separately verifies the historical 21-flight
artifact counts and aggregate TDoA/position metrics. Together, the tests protect
two levels:

1. sample-level preprocessing behavior on an inspectable fixture;
2. experiment-level thesis evidence from the compact historical artifacts.

The historical aggregates were not regenerated from raw flights, so they do
not provide sample-level state or prediction equivalence. That limitation
remains explicit.

## Reference-update policy

Expected files must not be regenerated automatically during a test. If an
intentional behavior change requires new values:

1. keep or archive the legacy reference;
2. add a failing demonstration of the intended difference;
3. document the algorithm and configuration change;
4. compare old and new outputs sample by sample and at the 21-flight level;
5. update references in the behavior-change commit only.

Rounding an aggregate metric is never sufficient justification for changing a
sample-level reference.

## Remaining regression gaps

The fixture does not yet freeze:

- 111-column feature construction and source/target row identities;
- event integration, ESKF states, covariance, quaternion, and accepted updates;
- CNN1/CNN2 predictions on frozen tensors;
- a compact real-flight slice with redistribution/provenance approval;
- raw-data regeneration of all 21 flights;
- MATLAB R2022b versus R2025b numerical compatibility.

These require extracted interfaces or authoritative source artifacts before a
reference can be created without guessing.

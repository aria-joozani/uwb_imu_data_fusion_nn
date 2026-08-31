# High-priority test results

## Scope

This document records Section 24 validation. The work adds discriminating
synthetic tests without changing the scientific algorithms. A passing
characterization test means the current behavior is understood; it does not
turn a documented defect into correct behavior.

## Test matrix

| Area | Status | Verification and finding |
|---|---|---|
| Metric correctness | PASS | Known scalar and 3-D examples verify RMSE, MAE, axis metrics, Euclidean metrics, and the separately named historical x+x+y diagnostic. |
| Active coordinate rotation | PARTIAL PASS | A scalar-first +90-degree z quaternion maps body +x to world +y through the ESKF constructor. Identity attitude with `[0 0 1] g` cancels gravity during stationary propagation. |
| Synchronization | PASS | Staggered timestamps verify linear gyroscope interpolation, enabled extrapolation, common-origin shifting, and strict removal of the ground-truth origin sample. |
| Sequence generation | NOT YET TESTABLE AS AN INTERFACE | Feature-window construction remains duplicated inside scripts. The legacy LSTM path concatenates flight rows before fixed-length reshape, so retained flight identity is insufficient to assert that a sequence cannot cross a flight boundary. |
| Inference normalization | PASS | The shared FNN model exposes the exact `muX`, `sigmaX`, `muY`, and `sigmaY` stored in its checkpoint, and its predictions match the former inline normalization/prediction formula to `1e-12`. |
| TDoA solver | PASS WITH P0 INCOMPATIBILITY | Both NLS solvers recover a known synthetic point to `1e-6` under their native `d_A-d_B` convention. Generated/ESKF measurements use `d_B-d_A`; the test proves they must currently be negated for the solver residual to be zero. |

## TDoA sign characterization

For ordered pair `(A,B)`, `generate_tdoa_from_gt` returns:

```text
d_generated = ||p - B|| - ||p - A||
```

`tdoa_residuals_3d` predicts:

```text
d_solver = ||p - A|| - ||p - B|| = -d_generated
```

At the known transmitter position, supplying generated measurements directly
therefore produces `residual = -2*d_generated`; supplying their negative
produces zero residual. This confirms the P0 sign defect already documented in
`math_implementation_review.md`. Section 24 does not fix it because that would
be an explicit behavior change requiring its own commit and evaluation.

## Coordinate-frame boundary

The automated test verifies only the transform actually executable in the
repository: MATLAB scalar-first quaternion rotation as used by `ESKF`. It does
not verify the physical IMU mounting, the body-axis labels, or the
survey-to-Vicon transform. The latter implementation and provenance are absent,
so fabricating an expected transform would create false assurance. These items
remain `UNKNOWN` as recorded in `coordinate_frames.md`.

## Sequence-generation finding

The FNN/CNN feature generator builds a 17-sample interval while processing one
flight script invocation, but it does not yet expose source/target indices as a
testable function. The legacy LSTM training script concatenates generated CSV
rows and reshapes fixed blocks after concatenation. Without preserved flight IDs
at that operation, a final partial block from one flight can be adjacent to the
next flight.

A meaningful boundary test requires the future feature/sequence interface to
accept group IDs and return source and target indices. Its contract should
assert that every window:

- contains exactly one flight/trajectory ID;
- uses only timestamps at or before its declared target;
- preserves the intended same-anchor-pair start and target rows;
- is discarded rather than joined across an experiment boundary.

Changing the current LSTM grouping now would alter training examples and is
therefore outside this behavior-preserving test step.

## Validation record

On 2026-09-01 with MATLAB R2025b:

- all 20 project tests passed;
- no test was failed or incomplete;
- the four added/modified Section 24 test files had zero Code Analyzer findings;
- the compact 21-flight historical baseline regression still passed;
- no production algorithm or saved checkpoint changed.

# Error-State Kalman Filter Review

## Executive finding

`library/ESKF.m` is a compact 9-error-state inertial/UWB filter with scalar TDoA updates. Its central model is recognizable, but it is not yet suitable as a thesis reference implementation: orientation used for inertial propagation can lag the stored quaternion, event timing is ambiguous, covariance injection is incomplete, biases are absent, and there are no filter-consistency tests. These are review findings only; no filter behavior was changed.

## Implemented state

The nominal state is split across arrays rather than represented as one object:

| Quantity | Storage | Shape per epoch | Meaning |
|---|---|---:|---|
| Prior position/velocity | `Xpr` | 1x6 | `[px py pz vx vy vz]` |
| Posterior position/velocity | `Xpo` | 1x6 | same |
| Orientation | `q_list` | 1x4 | MATLAB scalar-first quaternion |
| Rotation history | `R_list` | 3x3 | rotation made from predicted quaternion |
| Active rotation | `R` | 3x3 | reused by propagation; not reliably synchronized |
| Prior covariance | `Ppr` | 9x9 | covariance of `[dp dv dtheta]` |
| Posterior covariance | `Ppo` | 9x9 | same |
| Specific force history | `f` | 1x3 | accelerometer after multiplication by 9.81 |
| Angular-rate history | `omega` | 1x3 | gyroscope after degrees-to-radians conversion |

There are no accelerometer-bias or gyroscope-bias states. The state dimension is therefore 6 nominal translational variables plus a separately stored quaternion, with 9 error variables.

## Initialization

The calling scripts use a fixed initial condition for every flight:

- position approximately `[1.25 0 0.07]` m;
- zero velocity;
- identity quaternion `[1 0 0 0]`;
- caller-defined 9x9 covariance;
- fixed UWB lever arm `[-0.01245 0.00127 0.0908]` m.

This does not use the first available ground-truth pose or estimate initial roll/pitch from gravity. Whether the fixed state matches all constellations and trajectories is **UNKNOWN**. Initialization error is currently mixed into algorithm performance.

`R_list(1,:,:)` is allocated but not initialized, while `R` is initialized. Any consumer of the first history element receives a zero matrix.

## Prediction path

When an IMU event is detected, `predict`:

1. Converts acceleration from g to m/s² and angular rate from deg/s to rad/s.
2. Computes world acceleration as `R*f - [0;0;9.81]`.
3. Uses constant-acceleration position and velocity updates.
4. Right-multiplies the previous quaternion by an exponential-map increment.
5. Propagates the 9x9 error covariance.
6. Copies prior state and covariance into posterior slots pending a UWB update.

When no new IMU event is detected, it repeats the previous `f` and `omega` and still integrates them over `dt`. That is a zero-order hold. It is reasonable only if `dt` represents the interval since the previous integration event and the event scheduler is correct.

### Defect: rotation-state lag

In the IMU branch, the filter computes and stores `q_pr`, then executes

```matlab
obj.R_list(k, :, :) = quat2rotm(compact(q_pr));
obj.R = quat2rotm(compact(qk_1));
```

The reusable rotation is set from the previous quaternion, not the new quaternion. On the following call, acceleration and covariance propagation use this stale value. The non-IMU branch does not update `obj.R` at all. A quaternion correction in `UWB_correct` also does not refresh it. This is a high-confidence implementation defect, but its correction must be protected by a reference trajectory test because it changes numerical results.

### Ground-plane rule

If predicted z is negative, the implementation sets indices 3:6 to zero: z and all three velocity components. It does not update covariance to reflect this constraint. This is not a Kalman measurement update and can create an inconsistent nominal/covariance pair. The intended physical constraint—floor contact, flight-volume bound, or emergency guard—is undocumented.

### Quaternion handling

MATLAB's `quaternion` operations generally return normalized rotation quaternions for well-formed inputs, but the code does not explicitly assert norm, sign continuity, or finiteness. Small-angle composition is correct in form. The multiplication side fixes the perturbation convention and must agree with the Jacobian and covariance-reset convention; that agreement is currently untested.

## Process model and noise

The transition includes position-velocity coupling and attitude sensitivity to specific force. Current working-tree noise constants are 0.1 for acceleration and 0.01 rad/s for gyro. Git `HEAD` used materially larger values (2 and 0.1), so the worktree already contains an uncommitted tuning change.

The code constructs noise variance with `dt^2` and injects it into velocity and attitude. It does not document whether the constants are per-sample standard deviations, continuous-time noise densities, or tuned discrete increments. The dimensional interpretation is therefore **UNKNOWN**.

Missing model elements include:

- accelerometer and gyro biases and their random walks;
- scale factors and axis misalignment;
- gravity magnitude/location model beyond fixed 9.81;
- IMU/UWB time offset;
- lever-arm uncertainty;
- optional motion or drag model.

These are not automatically defects. They are model limitations that must be stated and evaluated against flight duration and sensor quality.

## TDoA correction

The correction selects anchors with zero-based IDs converted to MATLAB indices. It predicts `distance-to-B - distance-to-A`, including the rotated lever arm, and uses a scalar innovation variance of 0.05 m².

The analytical measurement Jacobian includes position and attitude sensitivity. Its actual dimensions are consistent:

- `G_x`: 1x10 with position, velocity, and four quaternion components;
- `G_dx`: 10x9 mapping `[dp dv dtheta]` to full perturbations;
- `G`: 1x9.

Several inline comments describe `G_dx` as 10x3 and `G` as 1x3. Those comments are incorrect and should be fixed during a behavior-preserving cleanup.

### Required Jacobian verification

The quaternion derivative is algebraically dense and has no test. Compare the 1x9 analytical Jacobian against central finite differences for:

- identity and nontrivial orientations;
- zero and nonzero lever arms;
- several anchor-pair orientations;
- points near, but not coincident with, an anchor.

The test must use the same right-multiplicative attitude perturbation as `q * zeta(dtheta)`.

### Innovation gate

The scalar statistic is `abs(innovation)/sqrt(S)` and the threshold is 5. This is a 5-sigma gate for a one-dimensional Gaussian innovation, not a generic Mahalanobis distance across multiple observations. The code records neither accepted/rejected flags nor NIS values, preventing diagnosis of whether a model performs well because of correction or because many observations were rejected.

### Posterior covariance

The simple `(I-KG)P` update is symmetrized. The numerically safer Joseph form is not used. More importantly, after injecting `dtheta` into the nominal quaternion, the error-state covariance is not transformed/reset for the new tangent point. This can matter after non-negligible corrections. Quaternion normalization is not asserted.

## Event scheduling and time alignment

The top-level fusion path merges timestamps and loops from epoch 2 onward. Its lookup is based on the preceding combined timestamp while state is stored at the current epoch, then a UWB correction is applied at that state. This creates an unresolved question:

```text
measurement timestamp t(k-1) -> propagation interval ? -> stored state t(k) -> correction timestamp ?
```

The neural baseline has a separate target-row alignment issue. Consequently, ESKF comparisons may combine filters receiving numerically different observations at different effective times.

A refactor must first define one event contract:

- state \(x_k\) is the posterior at timestamp \(t_k\);
- propagation uses IMU samples covering \((t_{k-1},t_k]\);
- every UWB observation stamped \(t_k\) corrects the prior at \(t_k\);
- multiple events sharing a timestamp have an explicit stable order.

No code should be reorganized around this contract until a tiny hand-built timeline test exposes the current behavior.

## Numerical and software robustness

| Finding | Severity | Evidence/impact |
|---|---|---|
| Active rotation lags quaternion | Critical | Direct assignment from `qk_1`; affects dynamics and Jacobian transition |
| Event timestamp semantics ambiguous | Critical | Previous-time lookup combined with current-row storage/correction |
| Attitude injection lacks covariance reset | High | Posterior covariance remains in old tangent space |
| No bias states | High for long trajectories | Systematic IMU errors integrate without estimation |
| Floor clamp resets all velocity | High | Discontinuous state mutation with no covariance update |
| No explicit quaternion checks | Medium | Norm/sign/finiteness failures are not diagnosed |
| Simple covariance update | Medium | Greater risk of loss of positive semidefiniteness |
| Fixed initial state across flights | Medium | Initialization error contaminates comparison |
| Gate/noise values not configuration | Medium | Tuning and provenance are hard to reproduce |
| `R_list(1)` remains zero | Low/medium | Incorrect first history value for downstream use |
| Misleading matrix-size comments | Low | Encourages incorrect future edits |

## Test plan before correction

1. `test_static_imu`: level stationary IMU should keep velocity and position bounded under the declared convention.
2. `test_constant_acceleration`: zero rotation and known acceleration should match closed-form p/v.
3. `test_constant_turn`: nonzero angular rate plus body-axis acceleration should expose rotation lag.
4. `test_measurement_sign`: synthetic TDoA innovation is zero at the true pose.
5. `test_measurement_jacobian`: analytical versus finite-difference 1x9 Jacobian.
6. `test_gate_boundary`: observations immediately below/above normalized residual 5.
7. `test_covariance_properties`: finite, symmetric, and positive semidefinite after long predict/update sequences.
8. `test_attitude_injection`: repeated small corrections compared with a reference multiplicative ESKF.
9. `test_event_timeline`: deterministic IMU/UWB events with duplicate timestamps.
10. `test_floor_constraint`: explicitly captures current z/velocity mutation before deciding its future.

## Recommended correction order

1. Freeze a deterministic legacy fixture and record current outputs.
2. Extract pure TDoA measurement and Jacobian functions without changing formulas.
3. Add the synthetic sign and finite-difference tests.
4. Define and test event-time semantics.
5. Synchronize `R` with the corrected quaternion and quantify the delta.
6. Add quaternion assertions and covariance PSD diagnostics.
7. Implement/reset covariance consistently and consider Joseph form.
8. Move noise, gate, gravity, lever arm, and initial state into named configuration.
9. Only then evaluate bias-state augmentation as a separately reported model variant.

Each algorithmic change must produce a before/after experiment with identical data split, observation stream, initialization, and metrics. Combining timing, sign, covariance, and model-order changes in one patch would make attribution impossible.

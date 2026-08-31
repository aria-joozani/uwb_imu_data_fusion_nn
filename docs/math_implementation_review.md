# Mathematical Implementation Review

## Scope and status

This document records the mathematics that the repository currently implements. It is an audit, not a corrected specification. No algorithm was changed while preparing it. Statements marked **inferred** follow from code and data; statements marked **UNKNOWN** need an experiment, source publication, or sensor specification.

The reviewed entry scripts are organized under `scripts/{preprocessing,evaluation}/`; reusable equations now reside in the corresponding `src/{uwb,localization,eskf}/` stages.

## Core conventions

| Quantity | Symbol | Implemented representation | Unit/status |
|---|---:|---|---|
| World position | \(p^W\) | 3-vector | m |
| Body velocity | \(v^W\) | 3-vector in world axes | m/s |
| Accelerometer sample | \(f^B\) | raw CSV values multiplied by 9.81 in ESKF | g in CSV, m/s² after conversion (**inferred**) |
| Gyroscope sample | \(\omega^B\) | raw CSV values multiplied by \(\pi/180\) | deg/s in CSV, rad/s after conversion (**inferred**) |
| Quaternion | \(q_{WB}\) | MATLAB scalar-first `[qw qx qy qz]` inside ESKF | unitless; direction inferred from use |
| Anchor positions | \(a_A^W,a_B^W\) | rows of constellation table | m |
| UWB lever arm | \(t_{BU}^B\) | `[-0.01245; 0.00127; 0.0908]` | m (**inferred**) |
| TDoA observation | \(z_{BA}\) | scalar range difference, not a time | m |

The raw pose CSV stores quaternion components as `[qx qy qz qw]`; the ESKF stores `[qw qx qy qz]`. See `coordinate_frames.md` for frame uncertainties.

## TDoA measurement model

### Implemented label convention

For a tag/UWB position \(p\) and ordered anchor pair \((A,B)\), dataset generation and ESKF correction use

\[
h_{BA}(p) = \|p-a_B\|_2 - \|p-a_A\|_2.
\]

Purpose: express the measured arrival-time difference as an equivalent path-length difference. Inputs and outputs are in metres. `generate_tdoa_from_gt.m` declares a speed-of-light variable but does not use it; therefore the value is not seconds or nanoseconds.

The ideal neural target at the later same-pair event \(l\) is

\[
y_l = h_{BA}(p_l^{GT}).
\]

The ESKF prediction includes the IMU-to-UWB lever arm:

\[
p_U^W = p_I^W + R_{WB}(q)t_{BU}^B,
\qquad
\hat z = \|p_U^W-a_B^W\| - \|p_U^W-a_A^W\|.
\]

The innovation is \(r=z-\hat z\).

### Sign inconsistency

`src/localization/tdoa_residuals_3d.m` and the duplicate local residual in `inference_tdoa.m` instead predict

\[
\|p-a_A\| - \|p-a_B\|,
\]

then subtract the stored observation. This is the negative of the generator/ESKF convention. Unless `d_vec` is negated before these solvers are called—and it is not visibly negated—the standalone nonlinear least-squares position path has a sign defect.

Verification required: one synthetic point with known anchors must produce the same signed value through generation, ESKF measurement prediction, and both NLS solvers.

## Dataset sample construction

For two successive events \(k<l\) having the same ordered pair, the generator interpolates 17 IMU samples on the interval and flattens them in time-major order:

\[
x_{1:102} = [f_1^T,\omega_1^T,f_2^T,\omega_2^T,\ldots,f_{17}^T,\omega_{17}^T].
\]

It appends

\[
x_{103:108}=[(a_A^W)^T,(a_B^W)^T],
\quad x_{109}=z_k,
\quad x_{110}=z_l,
\quad y=h_{BA}(p_l^{GT}).
\]

The working-tree generator uses measured \(z_k\) in feature 109, although the header calls it `uwb_tdoA_last_gt`. Git `HEAD` used the ideal value at \(k\). This is a material, currently uncommitted experiment change. The output is a corrected/ideal scalar TDoA at the later event, not a 2-D or 3-D position.

## Synchronization and resampling

`data_extractor.m` performs these numerical operations:

1. Removes `NaN` values independently from each extracted column.
2. Interpolates gyroscope axes to accelerometer timestamps using linear interpolation with extrapolation.
3. Shifts streams to a common minimum time.
4. Downsamples IMU and each pair-specific UWB stream with a factor currently equal to 8.
5. Interpolates ground-truth position at UWB event times with cubic spline interpolation.

Independent per-column deletion can destroy row correspondence if missingness differs between columns. Linear extrapolation can synthesize IMU values outside gyro support. Cubic splines can overshoot between pose samples. None of these operations currently records an interpolation-validity mask or maximum gap.

On the inspected representative flight, the reduced rates were about 126 Hz for IMU and 7.52 Hz for a given anchor pair, which explains the intended 17-sample interval. This is empirical, not a fixed-rate guarantee.

## Normalization and neural objective

All active training scripts implement per-column z-score normalization:

\[
\tilde x_j = \frac{x_j-\mu_{x,j}}{\sigma_{x,j}},
\qquad
\tilde y = \frac{y-\mu_y}{\sigma_y}.
\]

Inference restores physical units with

\[
\hat y = \tilde y_{pred}\sigma_y+\mu_y.
\]

The regression layers optimize mean squared error in normalized target space:

\[
L=\frac{1}{N}\sum_i(\tilde y_i-\hat{\tilde y}_i)^2.
\]

The scripts fit \(\mu\) and \(\sigma\) on the complete concatenated dataset before the train/validation/test split. That leaks validation and test statistics into training. Constant features would also yield zero standard deviation and division by zero; no epsilon or constant-column policy is implemented.

## Optional output smoothing

`inference_timesequnce.m` can apply an exponential smoother:

\[
y_t^{smooth}=\alpha\hat y_t+(1-\alpha)y_{t-1}^{smooth}.
\]

With \(\alpha=1\), the filter is the identity. The alternative hard-coded value is 0.5. The code does not derive \(\alpha\) from sample interval, so its effective bandwidth changes with event rate.

## ESKF nominal propagation

Ignoring the implementation issue described below, the intended discrete propagation is

\[
a^W_k=R_{WB}(q_{k-1})f^B_k-g e_3,
\]

\[
p_k=p_{k-1}+v_{k-1}\Delta t+\tfrac12 a^W_k\Delta t^2,
\qquad
v_k=v_{k-1}+a^W_k\Delta t,
\]

\[
q_k=q_{k-1}\otimes \zeta(\omega_k\Delta t),
\]

where

\[
\zeta(\phi)=
\begin{cases}
[1,0,0,0], & \|\phi\|=0,\\
[\cos(\|\phi\|/2),\;\phi^T\sin(\|\phi\|/2)/\|\phi\|],&\text{otherwise}.
\end{cases}
\]

The implementation computes `q_k` but assigns the reusable rotation matrix `obj.R` from `q_{k-1}` after propagation. From the next step onward, position/velocity propagation can therefore use a rotation one sample behind the stored quaternion. A UWB attitude correction also does not refresh `obj.R`.

There are no accelerometer or gyroscope bias states and no Earth rotation, Coriolis, scale-factor, or time-offset states.

## ESKF error covariance

The implemented error state is

\[
\delta x=[\delta p^T,\delta v^T,\delta\theta^T]^T\in\mathbb{R}^9.
\]

The state transition matrix is initialized as identity, with blocks

\[
F_{pv}=\Delta t I,
\quad F_{p\theta}=-\tfrac12\Delta t^2R[f]_{\times},
\quad F_{v\theta}=-\Delta t R[f]_{\times},
\quad F_{\theta\theta}=\exp([\omega\Delta t]_{\times}).
\]

Noise is constructed as

\[
Q_i=\operatorname{blkdiag}(\sigma_a^2\Delta t^2I_3,
\sigma_\omega^2\Delta t^2I_3),
\]

with current working-tree constants \(\sigma_a=0.1\) and \(\sigma_\omega=0.01\). It enters through

\[
F_i=\begin{bmatrix}0&0\\I&0\\0&I\end{bmatrix},
\qquad
P_k^-=F_xP_{k-1}^+F_x^T+F_iQ_iF_i^T.
\]

The dimensions in code are valid: `G_x` is 1x10, `G_dx` is 10x9, and the final measurement Jacobian is 1x9. Comments claiming 10x3 and 1x3 are wrong.

The chosen discrete noise scaling and units are not derived in the repository. In particular, an accelerometer white-noise model commonly contributes position-velocity cross terms; here noise is injected directly into velocity and attitude only. This must be treated as a tuning model until derived and tested.

## ESKF correction and gate

With scalar observation variance \(Q_z=(\sqrt{0.05})^2=0.05\ \mathrm{m}^2\), the code computes

\[
S=G P^-G^T+Q_z,
\qquad
d=\sqrt{r^2/S}=|r|/\sqrt S.
\]

It accepts a measurement when \(d<5\), then applies

\[
K=P^-G^T/S,
\quad \delta x=Kr,
\quad x^+=x^-+\delta x_{p,v},
\quad q^+=q^-\otimes\zeta(\delta\theta),
\]

and the simple covariance update

\[
P^+=(I-KG)P^-.
\]

The code symmetrizes \(P\), but does not use the Joseph form, reset the covariance after attitude error injection, or explicitly normalize the corrected quaternion. These omissions need consistency tests before changing them.

## Position and TDoA metrics

The centralized interface preserves scalar TDoA error
\(e_i=z_i^{GT}-\hat z_i\) and computes

\[
\mathrm{RMSE}_{TDoA}=\sqrt{\frac1N\sum_i e_i^2},
\qquad
\mathrm{MAE}_{TDoA}=\frac1N\sum_i|e_i|.
\]

For position error \(e_i=p_i^{est}-p_i^{GT}\), they report axis RMSE values and an overall Euclidean value

\[
\mathrm{RMSE}_{3D}=\sqrt{\frac1N\sum_i(e_{x,i}^2+e_{y,i}^2+e_{z,i}^2)}.
\]

The intended component-aggregated MA quantity appears to be

\[
\mathrm{MA}_{xyz}=\mathrm{MAE}_x+\mathrm{MAE}_y+\mathrm{MAE}_z.
\]

Historical `inference.m` and `fusion_eskf.m` implemented
`ma_x + ma_y + ma_x`, omitting z and counting x twice. The centralized
`calculate_position_metrics` function exposes that formula only as
`LEGACY_MA_XXY` and separately calculates canonical Euclidean `MAE_3D`.
Existing historical position-MA summaries remain invalid until recomputed from
sample-level errors.

`compare_tdoa_sim_vs_meas.m` labels `rmse*10e3` as millimetres. Metres-to-millimetres is multiplication by \(10^3\), so the printed value is ten times too large.

## Nonlinear least-squares position solve

The 3-D solver minimizes

\[
\min_p\sum_k r_k(p)^2
\]

with `lsqnonlin`; the 2-D solver holds \(z=z_0\). Window construction and optimizer settings are script-local. Besides the sign inconsistency, observability depends on anchor geometry and the number/diversity of pairs in the window. No geometry condition number, covariance, or failure-status metric is recorded.

## Priority verification matrix

| Priority | Mathematical risk | Minimal discriminating test |
|---|---|---|
| Critical | Generator/ESKF and NLS use opposite TDoA signs | Synthetic anchors and point; assert all predictions equal \(d_B-d_A\) |
| Critical | Baseline neural prediction is stored at the wrong aggregate UWB row | Tiny alternating-pair sequence with explicit source/target indices |
| High | Propagation rotation lags stored quaternion | Constant nonzero angular rate plus body acceleration; compare to reference integration |
| High | Position MA omits z and duplicates x | Hand-calculated 3-row error matrix |
| High | Full-dataset normalization leaks split information | Group split with held-out mean shift; assert training statistics use training only |
| High | Covariance update/injection consistency is unknown | PSD, symmetry, NEES/NIS, and finite-difference Jacobian tests |
| Medium | NLS geometry can be unobservable | Collinear/copanar anchor fixtures and solver-status assertions |
| Medium | Independent NaN deletion can desynchronize sensors | Staggered missing values with known row identity |
| Low | Millimetre reporting is scaled by 10 | 1 m synthetic error must print/return 1000 mm |

## Unknowns that block a definitive derivation

- The sensor manufacturers' exact IMU units and axis conventions.
- Whether raw TDoA has already been multiplied by the speed of light.
- The survey-to-Vicon rigid transform and its provenance.
- The intended continuous-time process-noise densities.
- Whether quaternion multiplication is intended as body-to-world or world-to-body under all callers.
- Hardware and firmware timing semantics for each raw timestamp.

These must be resolved from primary experiment records or controlled fixtures; guessing would make the implementation easier to read but not more correct.

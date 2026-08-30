# Data flow

## Scope

This document traces one network/ESKF sample through the effective implementation. Shapes are MATLAB shapes and therefore use 1-based indexing. `N`, `M`, and `K` vary by flight.

## Raw flight table

Input file example: `csv-data/const4/const4-trial1-tdoa2-traj1.csv`.

```text
Input shape: N x 27 table (representative N = 127,675 rows)
Output shape: unchanged table
Units: mixed; documented per field below
Purpose: container for asynchronously sampled sensor streams
Function responsible: load_experiment_dataset
```

The 27 columns are:

| Stream | Fields | Units inferred from code/data | Active use |
| --- | --- | --- | --- |
| UWB TDoA | `t_tdoa,idA,idB,tdoa_meas` | seconds, zero-based IDs, metres of range difference | yes |
| Accelerometer | `t_acc,acc_x,acc_y,acc_z` | seconds, g | yes |
| Gyroscope | `t_gyro,gyro_x,gyro_y,gyro_z` | seconds, degrees/s | yes |
| ToF | `t_tof,tof` | seconds, `UNKNOWN` | no |
| Optical flow | `t_flow,deltaX,deltaY` | seconds, `UNKNOWN` | no |
| Barometer | `t_baro,baro` | seconds, `UNKNOWN` | no |
| Vicon pose | `t_pose,pose_x,pose_y,pose_z,pose_qx,pose_qy,pose_qz,pose_qw` | seconds, metres, quaternion components | position yes; orientation extracted but unused |

The table is sparse: streams have different valid row counts and timestamps. Rows do not mean simultaneous measurements.

## Sensor extraction

### Ground truth

```text
Input shape: N x 27 table
Output shape: Nv x 8 double [t, x, y, z, qx, qy, qz, qw]
Units: seconds, metres, unit quaternion
Purpose: reference pose and ideal TDoA label generation
Function responsible: extract_gt -> deleteNAN
```

Each column has NaNs removed independently. The implementation assumes all eight Vicon columns share the same valid-row mask; it does not verify this.

### Accelerometer

```text
Input shape: N x 27 table
Output shape: Na x 4 double [t, ax, ay, az]
Units: seconds, g
Purpose: ESKF specific force and neural temporal features
Function responsible: extract_acc -> deleteNAN
```

The ESKF later multiplies xyz by 9.81, confirming that stored acceleration is treated as g rather than m/s^2.

### Gyroscope

```text
Input shape: N x 27 table
Output shape: Ng x 4 double [t, gx, gy, gz]
Units: seconds, degrees/s
Purpose: ESKF angular rate and neural temporal features
Function responsible: extract_gyro -> deleteNAN
```

The ESKF later multiplies xyz by `pi/180`.

### TDoA

```text
Input shape: N x 27 table
Output shape: Nu x 4 double [t, idA, idB, range_difference]
Units: seconds, integer anchor IDs, metres
Purpose: measured UWB observation
Function responsible: extract_tdoa -> deleteNAN
```

Although named TDoA, the measurement is already represented as distance difference in metres. The code never multiplies a measured value by the speed of light.

## Sensor synchronization and rate reduction

### Gyro-to-accelerometer synchronization

```text
Input shape: Ng timestamps + Ng values per axis; Na target timestamps
Output shape: Na x 3 synchronized gyro
Units: degrees/s
Purpose: create a six-channel IMU sample at accelerometer timestamps
Function responsible: interp_meas / interp1(...,'linear','extrap')
```

The synchronized IMU matrix is:

```text
imu = [acc_x acc_y acc_z gyro_x gyro_y gyro_z]  % Na x 6
```

Linear extrapolation is enabled outside the native gyro interval.

### Common time origin

```text
Input: first TDoA, IMU, and Vicon timestamps
Output: t_imu, t_tdoa, and retained t_vicon shifted by min_t
Units: seconds
Purpose: express active streams relative to a nominal common start
Function responsible: data_extractor.m
```

`min_t` is the minimum of the three first timestamps. Vicon samples are retained only where `t_vicon > min_t`, then shifted. TDoA and IMU arrays are shifted without trimming. End-of-flight overlap is not explicitly clipped.

### Downsampling

```text
Input shape: arbitrary R x C numeric array
Output shape: approximately ceil(R/8) x C
Units: unchanged
Purpose: reduce IMU and per-pair TDoA rates
Function responsible: downsamp
```

`downsamp` selects `1:2:end` three times. It is applied to the IMU timestamp vector and matrix separately and to each TDoA pair array separately. It is not applied to Vicon.

For the representative flight, IMU falls from about 1009 Hz to 126 Hz and each pair falls from about 60.1 Hz to 7.52 Hz.

### TDoA pair selection

```text
Input shape: Nu x 4 [t,idA,idB,value]
Output shape: eight variable-length arrays, then M x 4 sorted array
Units: seconds, IDs, metres
Purpose: keep the ring pairs 7->0,0->1,...,6->7 and downsample each pair independently
Function responsible: extract_tdoa_meas, downsamp, sortrows
```

Other anchor-pair combinations, if present, are discarded. The later feature builder uses only `idA` and assumes `idB` is the next ring anchor.

## Ground-truth TDoA label

### Vicon position at UWB timestamps

```text
Input shape: Nv x 3 Vicon position, Nv timestamps, M UWB timestamps
Output shape: M x 3 position
Units: metres in the local/Vicon frame
Purpose: position reference at each retained UWB measurement
Function responsible: three interp1(...,'spline') calls in data_extractor.m
```

No extrapolation option is supplied. Queries outside the Vicon interval produce non-finite values, which later create invalid generated rows.

### Ideal pair range difference

```text
Input shape: M x 3 ground-truth positions; M x [idA,idB]; 8 x 3 anchors
Output shape: M x 4 [t,idA,idB,ideal_range_difference]
Units: seconds, IDs, metres
Purpose: neural target and TDoA evaluation reference
Function responsible: simulate_tdoa_sequence_from_gt -> generate_tdoa_from_gt
```

For tag position `p` and pair `(A,B)`:

```text
y_gt = ||p - anchor_B|| - ||p - anchor_A||
```

The local variable `c` in `generate_tdoa_from_gt` is unused. The output is a range difference, not seconds or nanoseconds.

## Union event timeline

```text
Input shape: downsampled IMU timestamps + downsampled UWB timestamps
Output shape: K unique sorted timestamps and K x 11 integrated matrix
Units: seconds; sensor columns retain their native units
Purpose: interleave IMU and UWB events
Function responsible: duplicated loops in dataset_generator.m and inference scripts
```

Integrated columns are intended as:

```text
1      event time
2:4    accelerometer xyz [g]
5:7    gyro xyz [deg/s]
8:10   idA, idB, measured TDoA [m]
11     ideal TDoA [m]
```

Important indexing behavior: loop row `k` has time `t(k)`, but the code looks up sensor data at `t(k-1)` and stores it in row `k`. For ESKF prediction, using the left-endpoint IMU over `[t(k-1),t(k)]` may be intentional; for feature timestamp labeling and UWB correction, the intended convention is `UNKNOWN`.

## Network epoch construction

For each integrated row `k` holding a UWB event, the code:

1. reads `pair_id = idA`;
2. searches at most 100 union rows ahead for the next row `l` with the same `pair_id`;
3. collects IMU rows from `k:l`;
4. creates 17 equally spaced query times from just after `k` through `l`;
5. linearly interpolates/extrapolates six IMU channels at those times;
6. attaches the two ring-anchor positions;
7. attaches measured TDoA at `k` and measured TDoA at `l`;
8. attaches ideal TDoA at `l` as the target.

```text
Input shape: variable event interval k:l
Output shape: 19 x 6 temporary matrix
Units: rows 1:17 mix g and deg/s; row 18 metres; row 19 metres
Purpose: fixed-size neural example
Function responsible: dataset_generator.m; duplicated in inference variants
```

Temporary layout:

```text
rows 1:17, cols 1:6  = [acc xyz, gyro xyz]
row 18, cols 1:3     = anchor A xyz
row 18, cols 4:6     = anchor B xyz
row 19, col 1        = measured TDoA at k
row 19, col 2        = measured TDoA at l
row 19, col 3        = ideal TDoA at l (generation only)
row 19, cols 4:6     = unused zeros
```

The matrix is flattened time/row-major by transposing then using MATLAB column-major `(:)`. Values 1:110 are inputs; value 111 is the label. Values 112:114 are unused.

The generator preallocates one epoch per UWB row but does not shrink to the actual counter `m`. On the representative file this leaves one all-zero row and eight non-finite rows. Training removes rows with non-finite inputs/target but keeps the all-zero row.

## Training flow

```text
Input shape: generated tables, each Rf x 111
Output shape before split: N x 110 X and N x 1 Y
Units: physical values before z-score; dimensionless after z-score
Purpose: supervised scalar regression
Function responsible: train_tdoa_net1.m / train_tdoa_cnn_net1.m / train_tdoa_cnn_net2.m
```

Current reduced dataset inventory:

```text
38 unique CSVs
269,535 rows before invalid-row removal
43 list entries because one 7,304-row flight is listed six times
306,055 effective concatenated rows before invalid-row removal
```

Normalization:

```text
Xn(:,j) = (X(:,j) - muX(j)) / sigmaX(j)
Yn      = (Y - muY) / sigmaY
```

The statistics are calculated over the complete concatenated dataset before a random 70/15/15 epoch split. FNN retains `N x 110`; CNN transposes and reshapes to `110 x 1 x 1 x N`.

Loss is MATLAB regression-layer mean squared error on normalized `Y`.

## Inference flow

```text
Input shape: one 19 x 6 feature matrix
Output shape: FNN 1 x 110 or CNN 110 x 1 x 1 x 1 -> scalar normalized prediction
Units: normalized input/output; denormalized prediction in metres
Purpose: estimate ideal TDoA at target epoch
Function responsible: inference.m and predict(net,...)
```

Denormalization:

```text
y_m = y_normalized * sigmaY + muY
```

Baseline `inference.m` stores target-`l` predictions sequentially in `uwb_enhanced(m)` and later treats them as aligned to UWB row `m`. This is not equivalent to mapping the prediction to `l`. `inference_timesequnce.m` explicitly maps the target integrated index back to a UWB row.

## ESKF flow

At each union interval:

```text
Input: previous position/velocity/quaternion/covariance, IMU sample, dt
Output: predicted position/velocity/quaternion/covariance
Units: metres, m/s, unit quaternion, mixed covariance units
Purpose: inertial propagation
Function responsible: ESKF.predict
```

At each UWB event:

```text
Input: predicted state, scalar TDoA range difference, two anchors
Output: corrected state/quaternion/covariance if gate passes
Units: metres and corresponding covariance units
Purpose: constrain inertial drift with UWB
Function responsible: ESKF.UWB_correct
```

No Vicon position enters the ESKF. Vicon is used to generate neural labels and to evaluate the final state.

## Evaluation flow

### Scalar TDoA errors

```text
error_raw = ideal_tdoa - measured_tdoa
error_net = ideal_tdoa - enhanced_tdoa
RMSE = sqrt(mean(error.^2))
MAE  = mean(abs(error))
```

These scalar metrics produced the quoted thesis baseline values.

### Position errors

Vicon xyz is spline-interpolated to the union event timeline:

```text
position_error = eskf_position - interpolated_vicon_position
axis_rmse = sqrt(mean(axis_error.^2))
position_rmse_3d = sqrt(rmse_x^2 + rmse_y^2 + rmse_z^2)
                 = sqrt(mean(||position_error||_2^2))
```

The printed aggregate position MAE is currently incorrect (`ma_x + ma_y + ma_x`). The standard Euclidean position MAE `mean(vecnorm(error,2,2))` is not calculated by the baseline scripts.

## Sequence and boundary behavior

- Dataset generation runs one raw file at a time, so a 17-sample epoch does not cross a flight boundary.
- FNN/CNN epochs are independent after concatenation; random splitting places adjacent/correlated epochs from the same flight in different subsets.
- The historical deleted LSTM trainer concatenates files and reshapes every 20 rows without preserving file boundaries, so a sequence can cross from one flight to another.
- The 100 value in current feature code is a forward search limit in union-event rows, not a 100-sample history feature.
- The active baseline has no `n-100 -> n` state window.
- `inference_timesequnce.m` uses three prior pair transitions and applies an alpha filter with `alpha = 0.5` inside each target rollout.
- `inference_tdoa.m` uses a 12-measurement sliding window for nonlinear least-squares position.

## Known unresolved data-flow questions

- Is target-`l` prediction meant to be applied at `l` or deliberately compared at `k`?
- Is a raw TDoA measurement available in metres directly from the logging system, and what upstream conversion produced it?
- What exact event-time convention was intended by `t(k-1)` lookup and row-`k` storage?
- Are the sparse valid-row masks guaranteed identical across fields of each sensor?
- Are spline-generated labels outside the Vicon support supposed to be dropped, clipped, or extrapolated?
- Are the anchor survey and Vicon pose already expressed in exactly the same local frame?

All remain `UNKNOWN` until confirmed by tests, upstream dataset documentation, or the thesis methodology.

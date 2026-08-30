# Shared sensor preprocessing pipeline

## Interface

Section 20 separates sensor synchronization from rate/pair/label processing:

```matlab
overrides.dataset.csvFile = csvFile;
overrides.dataset.anchorFile = anchorFile;
config = load_experiment_config("legacy_pipeline", overrides);

dataset = load_experiment_dataset(config);
synchronized = synchronize_sensor_data(dataset, config);
processed = preprocess_sensor_data(synchronized, config);
```

The named `legacy_pipeline` configuration contains values extracted from the
former `data_extractor.m`; no new scientific parameter values were selected.

## Synchronization stage

`synchronize_sensor_data` performs only operations that establish aligned
active streams and a common time origin:

| Operation | Preserved setting |
|---|---|
| Gyroscope alignment | Linear interpolation to accelerometer timestamps |
| Gyroscope boundary behavior | Linear extrapolation enabled |
| Common origin | Minimum first timestamp among TDoA, accelerometer, and Vicon |
| Ground-truth retention | Only samples strictly after the common origin |
| Timestamp shift | Subtract the common origin from IMU, TDoA, and retained Vicon |
| IMU channel order | `[acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z]` |

Output dimensions and units are documented in the function header. This stage
does not downsample, filter anchor pairs, interpolate Vicon to UWB timestamps,
or create ground-truth-derived labels.

## Preprocessing stage

`preprocess_sensor_data` performs the remaining reviewed legacy operations:

| Operation | Preserved setting |
|---|---|
| IMU rate reduction | Select first sample of every 8 |
| UWB pair set/order | `7->0,0->1,1->2,...,6->7` |
| UWB rate reduction | Select first sample of every 8 independently per pair |
| Pair merge | Concatenate in configured pair order, then sort by timestamp |
| Vicon at UWB times | Cubic spline interpolation without extrapolation |
| Ideal TDoA | `distance(tag,B) - distance(tag,A)` in metres |

The processed structure explicitly separates timestamps, IMU samples, measured
TDoA, ideal TDoA, ground truth, anchors, units, and provenance metadata. Neural
feature-window construction is not part of this stage and remains a later
interface extraction; no empty `features/` module was created.

## Shared-use guarantee and limitation

The dataset generator and all current inference/fusion scripts invoke
`data_extractor.m`. That wrapper now calls the same loader, synchronization
function, and preprocessing function, so newly processed training-source and
inference flights share one implementation.

Training, validation, and test splits currently consume already-generated
111-column CSV files. Their raw sensor preprocessing happened before splitting;
the training scripts do not independently resynchronize raw sensors. Existing
generated CSVs cannot be retroactively proven to have used the current shared
function, so their historical provenance limitation remains documented.

## Legacy wrapper

`data_extractor.m` is retained as a thin compatibility script because its
callers still depend on base-workspace variables. It maps the explicit outputs
back to the old names (`t_imu`, `imu`, `tdoa_all`, `uwb`, `gt_data`,
`tdoa_sim`, and others). Removing that workspace contract belongs to the later
hidden-dependency refactor.

## Validation

Before extraction, the complete processed arrays for
`const4-trial1-tdoa2-traj1` were captured locally. After extraction, every
timestamp, IMU sample, shifted TDoA row, retained pair row, Vicon position,
interpolated ground-truth row, and ideal TDoA row compared exactly with
`isequaln`.

The validated output contains 15,960 IMU samples, 7,304 UWB rows, and 25,363
retained ground-truth rows. The named configuration, both processing functions,
loader dispatch, and compatibility wrapper have zero MATLAB Code Analyzer
findings. The historical baseline retained 21 flights, 336 long-form rows, and
576 summaries with unchanged headline metrics.

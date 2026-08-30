# Dataset loading interface

## Interface

Section 19 introduces one explicit loader for a raw flight and its matching
anchor survey:

```matlab
config.dataset.csvFile = fullfile(projectRoot, ...
    "csv-data", "const4", "const4-trial1-tdoa2-traj1.csv");
config.dataset.anchorFile = fullfile(projectRoot, ...
    "survey-results", "anchor_const4_survey.txt");

dataset = load_experiment_dataset(config);
```

The loader performs file import, schema validation, sparse-stream extraction,
and anchor-survey parsing. It deliberately does not synchronize sensors,
shift timestamps, downsample, filter anchor pairs, interpolate ground truth,
or generate ideal TDoA. Those are preprocessing responsibilities.

## Returned structure

| Field | Shape | Units | Meaning |
|---|---:|---|---|
| `rawTable` | N x 27 table | mixed | Original sparse flight table; optional retention |
| `timestamps.tdoa` | Nu x 1 | s | Native UWB timestamps |
| `timestamps.accelerometer` | Na x 1 | s | Native accelerometer timestamps |
| `timestamps.gyroscope` | Ng x 1 | s | Native gyro timestamps |
| `timestamps.groundTruth` | Nv x 1 | s | Native Vicon timestamps |
| `uwb.tdoa` | Nu x 4 | s, IDs, m | `[time,idA,idB,range_difference]` |
| `imu.accelerometer` | Na x 4 | s, g | `[time,ax,ay,az]` |
| `imu.gyroscope` | Ng x 4 | s, deg/s | `[time,gx,gy,gz]` |
| `groundTruth.pose` | Nv x 8 | s, m, quaternion | `[time,xyz,qx,qy,qz,qw]` |
| `anchors.positions` | 8 x 3 | m | Surveyed anchor positions |
| `anchors.quaternions` | 8 x 4 | unitless | Survey order `[qx,qy,qz,qw]` |
| `anchors.names` | 8 x 1 | n/a | `an0` through `an7` |
| `metadata` | scalar struct | mixed | Provenance, counts, units, and frame uncertainty |

The exact local coordinate-frame orientation remains unknown and is marked
accordingly rather than inferred.

## Compatibility boundary

`scripts/preprocessing/data_extractor.m` now uses this loader and then exposes
the former workspace variables (`data`, `gt_pose`, `tdoa`, `acc`, `gyr`,
`anchor_position`, and related anchor metadata). Existing dataset-generation
and inference scripts therefore retain their current downstream behavior while
sharing one validated loading implementation.

## Validation

The loader is accepted when a representative const4 flight produces tables,
sensor arrays, anchor positions, anchor quaternions, names, and sample counts
identical to the former inline loading logic. Missing files, missing required
columns, invalid anchor records, and incomplete surveys fail with explicit
error identifiers.

Validation on `const4-trial1-tdoa2-traj1` passed with 127,675 raw rows,
58,402 TDoA samples, 127,675 accelerometer samples, 127,675 gyroscope samples,
and 25,363 ground-truth poses. The imported table, every active extracted
array, anchor positions, quaternions, and names were exactly equal to the
former direct-loading result. The loader and compatibility wrapper have zero
MATLAB Code Analyzer findings. The historical baseline remained 21 flights,
336 long-form rows, and 576 summaries.

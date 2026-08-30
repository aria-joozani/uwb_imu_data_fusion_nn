# Dataset structure

## Dataset layers

The repository contains four distinct dataset layers:

1. raw multi-sensor flight CSVs under `csv-data/const*/`;
2. processed anchor surveys under `survey-results/`;
3. generated supervised-learning CSVs under `export-data-set/` and `export-data-set-r/`;
4. compact summaries under `artifacts/baseline/`, generated predictions/plots under `result/`, and checkpoints under `models/{active,legacy}/`.

Raw/generated datasets and the large result tree are ignored by `.gitignore`; compact baseline evidence and reviewed checkpoints are tracked. The datasets still have no immutable manifest.

## Raw schema

Every inspected raw flight CSV has the same 27-column schema:

```text
t_tdoa,idA,idB,tdoa_meas,
t_acc,acc_x,acc_y,acc_z,
t_gyro,gyro_x,gyro_y,gyro_z,
t_tof,tof,
t_flow,deltaX,deltaY,
t_baro,baro,
t_pose,pose_x,pose_y,pose_z,pose_qx,pose_qy,pose_qz,pose_qw
```

“Samples” in the inventory below means CSV data rows, not valid samples for every sensor. Each sparse sensor stream has its own valid count.

## Raw flight inventory

| Dataset | Constellation | Trial | Trajectory | Rows | Used for by current source |
| --- | --- | --- | --- | ---: | --- |
| const1-trial1-tdoa2 | 1 | 1 | UNKNOWN | 142226 | generated/training |
| const1-trial1-tdoa3 | 1 | 1 | UNKNOWN | 125374 | inactive |
| const1-trial2-tdoa2 | 1 | 2 | UNKNOWN | 123428 | generated/training |
| const1-trial2-tdoa3 | 1 | 2 | UNKNOWN | 123196 | inactive |
| const1-trial3-tdoa2 | 1 | 3 | UNKNOWN | 124537 | generated/training |
| const1-trial3-tdoa3 | 1 | 3 | UNKNOWN | 123767 | inactive |
| const1-trial4-tdoa2 | 1 | 4 | UNKNOWN | 123337 | generated/training |
| const1-trial4-tdoa3 | 1 | 4 | UNKNOWN | 123586 | inactive |
| const1-trial5-tdoa2 | 1 | 5 | UNKNOWN | 124075 | generated/training |
| const1-trial5-tdoa3 | 1 | 5 | UNKNOWN | 123869 | inactive |
| const1-trial6-tdoa2 | 1 | 6 | UNKNOWN | 122769 | generated/training |
| const1-trial6-tdoa3 | 1 | 6 | UNKNOWN | 124466 | inactive |
| const2-trial1-tdoa2 | 2 | 1 | UNKNOWN | 124393 | generated/training |
| const2-trial1-tdoa3 | 2 | 1 | UNKNOWN | 128916 | inactive |
| const2-trial2-tdoa2 | 2 | 2 | UNKNOWN | 123844 | generated/training |
| const2-trial2-tdoa3 | 2 | 2 | UNKNOWN | 125024 | inactive |
| const2-trial3-tdoa2 | 2 | 3 | UNKNOWN | 130415 | generated/training |
| const2-trial3-tdoa3 | 2 | 3 | UNKNOWN | 124115 | inactive |
| const2-trial4-tdoa2 | 2 | 4 | UNKNOWN | 124584 | generated/training |
| const2-trial4-tdoa3 | 2 | 4 | UNKNOWN | 126331 | inactive |
| const2-trial5-tdoa2 | 2 | 5 | UNKNOWN | 126983 | generated/training |
| const2-trial5-tdoa3 | 2 | 5 | UNKNOWN | 124868 | inactive |
| const2-trial6-tdoa2 | 2 | 6 | UNKNOWN | 126028 | generated/training |
| const2-trial6-tdoa3 | 2 | 6 | UNKNOWN | 126846 | inactive |
| const3-trial1-tdoa2 | 3 | 1 | UNKNOWN | 136380 | generated/training |
| const3-trial1-tdoa3 | 3 | 1 | UNKNOWN | 124505 | inactive |
| const3-trial2-tdoa2 | 3 | 2 | UNKNOWN | 130622 | generated/training |
| const3-trial2-tdoa3 | 3 | 2 | UNKNOWN | 105517 | inactive |
| const3-trial3-tdoa2 | 3 | 3 | UNKNOWN | 127587 | generated/training |
| const3-trial3-tdoa3 | 3 | 3 | UNKNOWN | 102637 | inactive |
| const3-trial4-tdoa2 | 3 | 4 | UNKNOWN | 128824 | generated/training |
| const3-trial4-tdoa3 | 3 | 4 | UNKNOWN | 124771 | inactive |
| const3-trial5-tdoa2 | 3 | 5 | UNKNOWN | 134022 | generated/training |
| const3-trial5-tdoa3 | 3 | 5 | UNKNOWN | 125365 | inactive |
| const3-trial6-tdoa2 | 3 | 6 | UNKNOWN | 127207 | generated/training |
| const3-trial6-tdoa3 | 3 | 6 | UNKNOWN | 124620 | inactive |
| const3-trial7-tdoa2-manual1 | 3 | 7 | manual1 | 68483 | generated/training |
| const3-trial7-tdoa2-manual2 | 3 | 7 | manual2 | 125906 | generated/training |
| const3-trial7-tdoa3-manual3 | 3 | 7 | manual3 | 119028 | inactive |
| const3-trial7-tdoa3-manual4 | 3 | 7 | manual4 | 166942 | inactive |
| const4-trial1-tdoa2-traj1 | 4 | 1 | 1 | 127675 | generated, active training, evaluation; sixfold listed weight |
| const4-trial1-tdoa2-traj2 | 4 | 1 | 2 | 131391 | generated, active training, evaluation |
| const4-trial1-tdoa2-traj3 | 4 | 1 | 3 | 128434 | generated, active training, evaluation |
| const4-trial1-tdoa3-traj1 | 4 | 1 | 1 | 129350 | inactive |
| const4-trial1-tdoa3-traj2 | 4 | 1 | 2 | 127231 | inactive |
| const4-trial1-tdoa3-traj3 | 4 | 1 | 3 | 130043 | inactive |
| const4-trial2-tdoa2-traj1 | 4 | 2 | 1 | 128811 | generated, active training, evaluation |
| const4-trial2-tdoa2-traj2 | 4 | 2 | 2 | 127568 | generated, active training, evaluation |
| const4-trial2-tdoa2-traj3 | 4 | 2 | 3 | 127622 | generated, active training, evaluation |
| const4-trial2-tdoa3-traj1 | 4 | 2 | 1 | 128760 | inactive |
| const4-trial2-tdoa3-traj2 | 4 | 2 | 2 | 126933 | inactive |
| const4-trial2-tdoa3-traj3 | 4 | 2 | 3 | 128160 | inactive |
| const4-trial3-tdoa2-traj1 | 4 | 3 | 1 | 127383 | generated, active training, evaluation |
| const4-trial3-tdoa2-traj2 | 4 | 3 | 2 | 127979 | generated, active training, evaluation |
| const4-trial3-tdoa2-traj3 | 4 | 3 | 3 | 129841 | generated, active training, evaluation |
| const4-trial3-tdoa3-traj1 | 4 | 3 | 1 | 127061 | inactive |
| const4-trial3-tdoa3-traj2 | 4 | 3 | 2 | 127452 | inactive |
| const4-trial3-tdoa3-traj3 | 4 | 3 | 3 | 128644 | inactive |
| const4-trial4-tdoa2-traj1 | 4 | 4 | 1 | 127914 | generated, older training, evaluation |
| const4-trial4-tdoa2-traj2 | 4 | 4 | 2 | 125405 | generated, older training, evaluation |
| const4-trial4-tdoa2-traj3 | 4 | 4 | 3 | 129452 | generated, older training, evaluation |
| const4-trial4-tdoa3-traj1 | 4 | 4 | 1 | 127134 | inactive |
| const4-trial4-tdoa3-traj2 | 4 | 4 | 2 | 127484 | inactive |
| const4-trial4-tdoa3-traj3 | 4 | 4 | 3 | 127288 | inactive |
| const4-trial5-tdoa2-traj1 | 4 | 5 | 1 | 128487 | evaluation only |
| const4-trial5-tdoa2-traj2 | 4 | 5 | 2 | 127215 | evaluation only |
| const4-trial5-tdoa2-traj3 | 4 | 5 | 3 | 126685 | evaluation only |
| const4-trial5-tdoa3-traj1 | 4 | 5 | 1 | 126417 | inactive |
| const4-trial5-tdoa3-traj2 | 4 | 5 | 2 | 127951 | inactive |
| const4-trial5-tdoa3-traj3 | 4 | 5 | 3 | 127766 | inactive |
| const4-trial6-tdoa2-traj1 | 4 | 6 | 1 | 125613 | generated, active training, evaluation |
| const4-trial6-tdoa2-traj2 | 4 | 6 | 2 | 127496 | generated, active training, evaluation |
| const4-trial6-tdoa2-traj3 | 4 | 6 | 3 | 127041 | generated, active training, evaluation |
| const4-trial6-tdoa3-traj1 | 4 | 6 | 1 | 128452 | inactive |
| const4-trial6-tdoa3-traj2 | 4 | 6 | 2 | 127373 | inactive |
| const4-trial6-tdoa3-traj3 | 4 | 6 | 3 | 128470 | inactive |
| const4-trial7-tdoa2-manual1 | 4 | 7 | manual1 | 131834 | generated, active training, evaluation |
| const4-trial7-tdoa2-manual2 | 4 | 7 | manual2 | 118800 | generated, active training, evaluation |
| const4-trial7-tdoa2-manual3 | 4 | 7 | manual3 | 140760 | generated, active training, evaluation |

“Active training” refers to `train_tdoa_net1.m`, `train_tdoa_cnn_net1.m`, and `train_tdoa_cnn_net2.m`. “Older training” refers to older CNN scripts that use a different generated-data directory/list. The actual training provenance of each saved checkpoint is not recorded, so these labels describe source intent, not proven checkpoint lineage.

## Reduced generated dataset inventory

The 38 unique files under `export-data-set-r/` have 269,535 total rows before invalid-row filtering:

| Group | Files | Generated rows | Current use |
| --- | ---: | ---: | --- |
| const1 trials 1-6 | 6 | 44,777 | active training |
| const2 trials 1-6 | 6 | 44,580 | active training |
| const3 trials 1-6 | 6 | 43,358 | active training |
| const3 manual 1-2 | 2 | 10,301 | active training |
| const4 trials 1-3, trajectories 1-3 | 9 | 65,455 | active training and evaluation overlap |
| const4 trial 4, trajectories 1-3 | 3 | 19,584 | generated; omitted by newer active lists, included by older lists; evaluation |
| const4 trial 6, trajectories 1-3 | 3 | 20,317 | active training and evaluation overlap |
| const4 manual 1-3 | 3 | 21,163 | active training and evaluation overlap |

The training lists contain 43 entries and repeat the 7,304-row const4 trial1/trajectory1 file six times, producing 306,055 concatenated rows before invalid-row removal.

`export-data-set/` contains full-rate/older versions of the same 38 names plus a 4.45 GB `dataset_learning_all.mat`. Its precise generation configuration and valid sample count are `UNKNOWN`.

## Evaluation set

The 21 rows in the existing result spreadsheets are:

```text
const4 trials 1-6 x trajectories 1-3 = 18 flights
const4 trial7 x manual1-manual3       = 3 flights
```

All use `tdoa2` raw files and constellation-4 anchors. Fifteen of these flights are present in the newer training lists; older lists include eighteen.

## Anchor datasets

For each constellation, the processed survey TXT contains 8 positions and 8 quaternions. Active code uses positions only. The NPZ contents and raw-to-processed transformation are not consumed by repository code.

| Dataset | Constellation | Samples | Used for |
| --- | --- | ---: | --- |
| `anchor_const1_survey.txt` | 1 | 8 anchors | generated labels/features for const1 |
| `anchor_const2_survey.txt` | 2 | 8 anchors | generated labels/features for const2 |
| `anchor_const3_survey.txt` | 3 | 8 anchors | generated labels/features for const3 |
| `anchor_const4_survey.txt` | 4 | 8 anchors | generated labels/features and all 21 evaluations |

## Dataset integrity/provenance gaps

- No checksum manifest exists for raw/generated datasets.
- No script records which source revision generated each `_NN.csv`.
- The current generator list redundantly overwrites one output six times.
- The root `csv-data/const1-trial1-tdoa2_NN.csv` duplicates a generated artifact in an unexpected location.
- Trial/trajectory semantics for const1-3 are not encoded in filenames and remain `UNKNOWN`.
- `tdoa2` versus `tdoa3` meaning is not documented in repository source.
- Generated sample IDs, source row IDs, start/target timestamps, and flight IDs are discarded, preventing a direct split audit from the generated table alone.
- Some generated rows are non-finite or all-zero due to preallocation/window boundaries.
- No license, collection protocol, sensor calibration record, or privacy/ethics metadata was found.

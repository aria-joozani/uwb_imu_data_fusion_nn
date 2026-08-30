# Dependency map

## Active pipeline

```mermaid
flowchart TD
    RAW[Raw flight CSV<br/>27 sparse sensor columns]
    SURVEY[Processed anchor survey TXT<br/>8 positions + 8 quaternions]

    RAW --> EX[data_extractor.m]
    SURVEY --> EX
    EX --> EGT[extract_gt]
    EX --> ET[extract_tdoa]
    EX --> EA[extract_acc]
    EX --> EG[extract_gyro]
    EGT --> DN[deleteNAN]
    ET --> DN
    EA --> DN
    EG --> DN
    EG --> IM[interp_meas<br/>gyro -> accelerometer time]
    EA --> IM
    IM --> DS[downsamp x8]
    ET --> PAIRS[extract_tdoa_meas<br/>ring pairs 70,01,...,67]
    PAIRS --> DS
    EGT --> GTI[Vicon spline interpolation<br/>at downsampled UWB times]
    DS --> GTI
    GTI --> SIM[simulate_tdoa_sequence_from_gt]
    SURVEY --> SIM
    SIM --> GTF[generate_tdoa_from_gt<br/>dB - dA in metres]

    DS --> GEN[dataset_generator.m]
    SIM --> GEN
    SURVEY --> GEN
    GEN --> FEAT[17x6 IMU + 2x3 anchors<br/>+ 2 measured TDoA]
    GTF --> LABEL[ideal next-pair TDoA label]
    FEAT --> NNCSV[Generated 111-column CSV]
    LABEL --> NNCSV

    NNCSV --> TRAIN[train_tdoa_net1 / cnn_net1 / cnn_net2]
    TRAIN --> NORM[global zscore statistics]
    NORM --> SPLIT[random epoch 70/15/15 split]
    SPLIT --> CKPT[SeriesNetwork checkpoint<br/>net + mu/sigma X/Y]

    RAW --> INF[inference.m]
    SURVEY --> INF
    CKPT --> INF
    INF --> IFEAT[duplicated feature construction]
    IFEAT --> PRED[predict ideal TDoA]
    PRED --> TMET[TDoA RMSE/MAE]
    PRED --> ENH[replace measured TDoA]
    ENH --> ERUN[ESKF orchestration]
    DS --> ERUN
    ERUN --> ECLASS[library/ESKF.m]
    ECLASS --> PMET[position metrics]
    ECLASS --> PLOT[plot_pos / plot_pos_err / plot_traj]
    TMET --> LOG[result diary + figures]
    PMET --> LOG
    PLOT --> LOG
```

This graph represents current source dependencies, not the desired architecture. In particular, feature construction is not a shared function: the `FEAT` and `IFEAT` nodes are separate copies of similar code.

## Dataset-generation call chain

```text
dataset_generator_runner.m
  -> sets csv_file / anchors / export_csv_file in base workspace
  -> data_extractor.m
       -> addpath('library')
       -> extract_gt -> deleteNAN
       -> extract_tdoa -> deleteNAN
       -> extract_acc -> deleteNAN
       -> extract_gyro -> deleteNAN
       -> interp_meas
       -> downsamp
       -> extract_tdoa_meas
       -> simulate_tdoa_sequence_from_gt
            -> generate_tdoa_from_gt
  -> dataset_generator.m
       -> isin
       -> interp1
       -> array2table / writetable
```

Both called files are scripts. Their inputs and outputs are implicit workspace variables.

## Training dependencies

```mermaid
flowchart LR
    LIST[Hard-coded generated CSV list]
    READ[readtable + concatenate]
    SELECT[110 named inputs + 1 target]
    Z[zscore on complete data]
    R[randperm epoch split]
    ARCH[inline layer definition]
    OPT[inline trainingOptions]
    TN[trainNetwork]
    MAT[checkpoint MAT]

    LIST --> READ --> SELECT --> Z --> R --> TN --> MAT
    ARCH --> TN
    OPT --> TN
```

There is no shared dataset list, split function, normalizer, feature schema, model factory, or checkpoint manifest. The same 110 input names are copied into every training and PTQ script.

## Inference variants

| Entry point | Model stage | Localization stage | Distinguishing dependency |
| --- | --- | --- | --- |
| `inference.m` | Single-step FNN/CNN prediction; current file hard-codes FNN | `ESKF` | Sequential `uwb_enhanced(m)` assignment |
| `inference_timesequnce.m` | Pair-wise three-step autoregressive rollout plus alpha filter | `ESKF` | Explicit `uwb_row_at_time(target_idx)` assignment |
| `inference_tdoa.m` | Single-step CNN2 prediction | `solve_tdoa_nls_3d`/`2d` | Sliding window of 12 TDoAs; no ESKF |
| legacy `inference_lstm.m` | LSTM checkpoint under `networks/` | `ESKF` | Preserved historical path; not active baseline |
| `fusion_eskf.m` | None; raw measured TDoA | `ESKF` | Raw-filter reference path |

## ESKF internal dependencies

```mermaid
flowchart TD
    RUN[fusion_eskf or inference]
    INIT[ESKF constructor]
    P[predict]
    C[UWB_correct]
    Z[zeta small-angle quaternion]
    X[cross skew matrix]
    G[computeG_grad]
    MQ[MATLAB quaternion / quat2rotm]

    RUN --> INIT --> P
    P --> Z
    P --> X
    P --> MQ
    P --> C
    C --> G
    C --> Z
    C --> MQ
    G --> X
    G --> MQ
```

The class stores the complete state/covariance history, so memory allocation depends on the length of the union event timeline `K`.

## Results/reporting dependencies

```text
per-flight scripts
  -> diary TXT + FIG files
  -> manual/UNKNOWN aggregation process
  -> result_overall_tdoa_rms.xlsx
  -> result_overall_tdoa_ma.xlsx
  -> result_position_rms.xlsx
  -> plot_rms_ma.m / plot_position_rms.m
  -> thesis PNG figures
```

No code was found that constructs all three Excel summaries from the per-flight logs. This missing edge is a provenance gap.

## Deployment experiment dependencies

```mermaid
flowchart LR
    CSV[Generated CSVs] --> PREP[prepare_data_for_ptq.m]
    CKPT[CNN2 checkpoint] --> PREP
    PREP --> PMAT[prepared_data_for_ptq.mat]
    CKPT --> PTQ[ptq_tdoa_net.m]
    PMAT --> PTQ
    PTQ --> Q[Quantized MAT artifact]
    CKPT --> ONNX[exportNetwork.m]
    ONNX --> O[tdoa_net.onnx]
```

The ONNX output and quantized model were not found in the current inventory, so these paths are experimental/unverified.

## Standalone or obsolete candidates

- `ieee.m` has no reference from the active localization code.
- `plot_anchors_3d.m` and `plot_sampling_timeline.m` are standalone visualization helpers.
- `data_extractor.m` has optional extraction helpers for ToF, flow, and barometer, but the active neural/ESKF path does not call them.
- Root archives and older checkpoints are not code dependencies until selected manually.
- `uwb_imu_pipeline_diagram.py` is documentation generation, not runtime code, and refers to deleted LSTM scripts.

These files should not be deleted until their research provenance is established.

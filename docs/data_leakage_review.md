# Data leakage review

## Conclusion

The current training/evaluation methodology has **CRITICAL leakage risk**. This does not prove that every saved checkpoint used the exact current source lists, because checkpoint provenance is missing. It does prove that rerunning the current scripts would not produce a defensible held-out-flight evaluation.

The legacy results should be preserved as historical results. Leakage-safe splits must be added as new experiments, not silently substituted into the thesis baseline.

## Risk register

| ID | Severity | Risk | Evidence | Status |
| --- | --- | --- | --- | --- |
| DL-01 | CRITICAL | Same flight appears in training and 21-flight evaluation | 15/21 overlap in newer lists; 18/21 in older lists | confirmed in source |
| DL-02 | CRITICAL | Highly correlated epochs from one flight are randomly distributed across train/validation/test | `idx = randperm(N)` after concatenation | confirmed |
| DL-03 | HIGH | Normalization statistics use validation/test rows | `zscore` occurs before split | confirmed |
| DL-04 | HIGH | One flight is weighted sixfold and appears throughout all random subsets | duplicated path six times | confirmed |
| DL-05 | HIGH | Historical LSTM sequences can cross flight boundaries | files concatenated then reshaped every 20 rows | confirmed in deleted Git source |
| DL-06 | HIGH | PTQ calibration/test are drawn randomly from the same combined dataset used for training and include evaluation flights | `prepare_data_for_ptq.m` list and `randperm` | confirmed |
| DL-07 | MEDIUM/HIGH | Model selection and checkpoint choice may have used the same 21-flight results | many checkpoints/results, no selection log | UNKNOWN |
| DL-08 | MEDIUM | Adjacent feature rows share time-local dynamics and endpoint measurements even when not identical | next-same-pair windows from one continuous flight | confirmed structurally |
| DL-09 | CONTEXT-DEPENDENT | Current target uses data through target epoch `l` | features include IMU through `l` and measured TDoA at `l` | acceptable for denoising at `l`; future leak if claimed as pre-`l` prediction |
| DL-10 | LOW in current code | Ground truth appears as an inference feature | misleading name `uwb_tdoA_last_gt` | reviewed: current generator uses measured TDoA, not GT |
| DL-11 | MEDIUM | Generated rows lack flight/timestamp metadata, making later grouping/audit impossible after concatenation | 111 numeric columns only | confirmed |
| DL-12 | MEDIUM | Invalid/all-zero boundary rows can enter random subsets | representative generated file has one all-zero row; invalid rows removed, zero row retained | confirmed representative case |

## DL-01 - Train/evaluation flight overlap

Newer FNN/CNN1/CNN2 source lists include these const4 evaluation groups:

```text
trials 1, 2, 3: all three trajectories = 9 flights
trial 6: all three trajectories          = 3 flights
trial 7: all three manual flights        = 3 flights
total overlap                            = 15 of 21
```

They omit trials 4 and 5. Older CNN/LSTM lists also include trial 4, raising overlap to 18 of 21.

Impact: the 21-flight table is primarily an in-distribution/reused-flight result under the current sources, not a held-out-flight generalization result.

Required control:

- preserve `legacy_list` exactly for historical reproduction;
- introduce an explicit flight manifest with roles;
- fail validation if any flight ID is in more than one of train/validation/test;
- report generalization experiments separately.

## DL-02 - Random epoch split

After all selected files are concatenated, the scripts run:

```matlab
idx = randperm(N);
```

Individual epochs, not flights or contiguous groups, are split 70/15/15. Consecutive rows from a flight represent neighboring pair transitions and share motion regime, environment, anchor geometry, and often near-identical IMU/TDoA values.

Impact: validation/test loss can substantially overstate performance on unseen flights or environments.

Required control:

```text
split unit = flight (minimum)
optional split unit = trajectory or constellation
normalization fit = training rows only
window generation = within one source group only
```

## DL-03 - Normalization leakage

All active trainers calculate:

```matlab
[X, muX, sigmaX] = zscore(X);
[Y, muY, sigmaY] = zscore(Y);
```

before splitting. Thus validation/test mean and standard deviation influence the representation seen during training. `Y` statistics also include evaluation targets.

Required correction for new experiments:

1. split source groups;
2. compute `muX/sigmaX` and `muY/sigmaY` from training rows only;
3. apply the saved training statistics unchanged to validation/test/inference;
4. record zero-variance handling;
5. test that inference never recomputes statistics.

## DL-04 - Duplicate weighting

`const4-trial1-tdoa2-traj1_NN.csv` is listed six times. It has 7,304 rows. Five additional copies raise the combined reduced-data row count from 269,535 unique rows to 306,055 listed rows.

This causes identical rows to occur multiple times before random splitting, so exact duplicates can be placed in train and test. It also changes the effective constellation/trial weighting.

Severity is HIGH and becomes CRITICAL if the duplication was accidental and test loss was used as evidence of generalization.

## DL-05 - Historical LSTM boundary crossing

The deleted but checkpoint-producing LSTM trainer concatenates all files, normalizes globally, and then executes a fixed `sequenceLength = 20` reshape. It does not retain per-file boundaries.

Consequences:

- a 20-step sequence can end in one flight and continue in the next;
- labels are averaged across the 20 steps;
- chronological train/validation/test slicing occurs only after cross-file reshape;
- flight order in the hard-coded list determines subset composition.

Any future temporal model must generate sequences inside a named flight/trajectory group and store source IDs for every sequence.

## DL-06 - PTQ evaluation is not independent

`prepare_data_for_ptq.m` uses the same combined lists, saved global training statistics, and a new uncontrolled random split for 10% calibration and 15% test. It neither excludes training rows nor holds out evaluation flights.

This can measure quantization degradation on familiar data, but it cannot establish deployed generalization. The PTQ report must label the set accordingly or use the same immutable held-out split as floating-point evaluation.

## DL-07 - Model-selection leakage

There are multiple generations of FNN, CNN1, CNN2, CNN3, CNN5, and LSTM checkpoints, along with many per-flight figures. No record identifies:

- selection criterion;
- checkpoint chosen before or after inspecting 21-flight results;
- hyperparameter trials;
- validation metric used;
- seed or early-stopping iteration.

It is therefore `UNKNOWN` whether the 21-flight set also served as a model-selection set. Future experiments need a validation set distinct from the final test set and an experiment registry containing every attempted run.

## DL-08 - Overlapping/correlated feature windows

For each anchor pair, a row spans one pair occurrence to the next. The next generated row for that same pair starts at the previous row's target occurrence. Therefore adjacent pair-specific examples share an endpoint TDoA and are temporally adjacent. Different pair examples also overlap in IMU time.

Random row splitting puts such strongly related windows on both sides of the split. Group splitting by complete flight avoids this; a mere random non-overlapping row split is insufficient.

## DL-09 - Future-information semantics

The feature uses:

- IMU samples throughout `[k,l]`;
- measured TDoA at `k`;
- measured TDoA at `l`;
- target ideal TDoA at `l`.

This is valid if the task is “denoise/correct the TDoA measurement once the measurement at `l` has arrived.” It is leakage if the task is described as predicting the TDoA at `l` before observing `l`.

The task definition must explicitly say **current-epoch TDoA correction/denoising**, unless feature 110 and the endpoint IMU are removed in a separately evaluated forecasting experiment.

## DL-10 - Ground-truth feature audit

The column name `uwb_tdoA_last_gt` suggests ground truth, but current `dataset_generator.m` assigns measured TDoA at `k` to it. Inference uses the same measured value. Thus current source does not put Vicon-derived ground truth in the 110 network inputs.

However, Git HEAD assigned ideal TDoA to that feature before an uncommitted change. This provenance difference matters:

- a checkpoint trained with the old feature would require unavailable ground truth at inference or encounter a training/inference mismatch;
- current root checkpoint lineage is not documented.

Checkpoint/data hashes and a one-row feature reproduction are required to determine which semantics produced each model.

## Leakage-safe experiment designs

These are additional experiments, not silent replacements:

| Experiment | Train | Validation | Test | Question |
| --- | --- | --- | --- | --- |
| leave-one-flight-out | all but one flight | subset of training flights | one flight | unseen-flight generalization |
| leave-one-trajectory-out | other trajectories | grouped training subset | one trajectory across trials | trajectory-shape generalization |
| leave-one-constellation-out | three constellations | grouped subset | fourth constellation | geometry/environment generalization |
| trial-held-out | selected trials | distinct trial(s) | final trial(s) | clutter/dynamic condition generalization |
| thesis legacy | current lists/random rows | random rows | random rows plus 21-flight table | historical reproduction only |

Every split must be saved as a manifest before training and include source file, constellation, trial, trajectory/manual ID, role, row/window range, and checksum.

## Required automated checks

1. no source flight in more than one split role;
2. no exact generated row hash in both train and validation/test;
3. no sequence crosses a flight boundary;
4. normalization statistics equal training-only recomputation;
5. validation/test transforms reuse saved statistics;
6. no Vicon/ideal TDoA field in `X` for deployable inference;
7. target timestamp is not later than the declared availability time;
8. duplicate file paths rejected unless an explicit weight is configured;
9. PTQ test indices are a named subset of the floating-point held-out test set;
10. final-test metrics are not used for checkpoint selection.

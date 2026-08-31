# Centralized metric interface

## TDoA metrics

```matlab
metrics = calculate_tdoa_metrics(referenceTdoa, estimatedTdoa);
```

The preserved TDoA error direction is `error = reference - estimate`.

| Field | Definition |
|---|---|
| `RMSE` | `sqrt(mean(e.^2))` |
| `MAE` | `mean(abs(e))` |
| `MEDAE` | `median(abs(e))` |
| `P95` | 95th percentile of absolute error |
| `MAX` | maximum absolute error |
| `BIAS` | `mean(e)` |
| `STD` | sample standard deviation using `N-1` normalization |
| `COUNT` | number of scalar samples |
| `ERROR` | signed error vector |

Inputs and error outputs are TDoA range differences in metres, not time.

## Position metrics

```matlab
metrics = calculate_position_metrics(referencePosition, estimatedPosition);
```

Both inputs are `N x 3` xyz positions in metres. Position error preserves the
reviewed convention `error_xyz = estimate - reference`.

```text
RMSE_3D = sqrt(mean(dx.^2 + dy.^2 + dz.^2))
MAE_3D  = mean(sqrt(dx.^2 + dy.^2 + dz.^2))
```

`RMS_ALL` retains the thesis calculation
`sqrt(RMSE_X^2 + RMSE_Y^2 + RMSE_Z^2)` and is numerically identical to
`RMSE_3D`.

## Historical position-MA defect

Old scripts calculated `MAE_X + MAE_Y + MAE_X`, omitting z and counting x
twice. Section 22 does not silently relabel that value. It is exposed only as
`LEGACY_MA_XXY` for behavior comparison; canonical Euclidean position MAE is
`MAE_3D`.

Legacy evaluation scripts retain their old `ma_all` console variable by
assigning `LEGACY_MA_XXY`, while also calculating the correct canonical fields.
The saved position-MAE workbook remains all-NaN and was not overwritten.

## Adoption

Centralized metrics are used by training evaluation, active and legacy
inference, ESKF and NLS position evaluation, per-pair reporting, FP32/INT8
comparison, and simulated-versus-measured TDoA comparison. The remaining
inline RMS in `inference_tdoa.m` is an NLS fit-residual diagnostic, not a
reference-vs-estimate localization metric.

## Validation

Synthetic scalar errors `[1,0,-1]` produced RMSE `sqrt(2/3)`, MAE `2/3`, zero
bias, and sample standard deviation 1. Synthetic position errors `[3,4,0]` and
`[0,0,12]` produced `RMSE_3D = sqrt(169/2)`, `MAE_3D = 8.5`, and preserved
legacy aggregate 5. `RMS_ALL` and `RMSE_3D` matched within floating-point
tolerance.

Both central functions have zero MATLAB Code Analyzer findings. The historical
baseline remained 21 flights, 336 long-form rows, and 576 summaries.

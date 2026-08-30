# Neural TDoA model interface

## Scientific contract

The reviewed neural networks predict one ideal/corrected TDoA range difference
in metres. They do not predict position or position error. Section 21 therefore
uses domain-accurate names:

```matlab
config = tdoa_model_config("cnn2");
model = load_tdoa_correction_model(config);
prediction = predict_tdoa_correction(model, rawFeatures);
```

`rawFeatures` is always `N x 110` in the existing documented feature order.
The returned prediction is `N x 1` in metres.

## Supported active models

| Type | Checkpoint | Internal input layout |
|---|---|---|
| `fnn` / `fcc1` | `models/active/trained_tdoa_net_fcc1.mat` | `N x 110` feature rows |
| `cnn1` | `models/active/trained_tdoa_net_cnn_1.mat` | `110 x 1 x 1 x N` |
| `cnn2` | `models/active/trained_tdoa_net_cnn_2.mat` | `110 x 1 x 1 x N` |
| `cnn3` | `models/active/trained_tdoa_net_cnn_3.mat` | `110 x 1 x 1 x N` |

The configuration factory is a centralized runtime mapping, not proof of
checkpoint training provenance and not automatic model selection.

## Loader responsibilities

`load_tdoa_correction_model`:

- resolves the configured checkpoint;
- requires `net`, `muX`, `sigmaX`, `muY`, and `sigmaY`;
- validates the 110 input statistics and scalar output statistics;
- rejects nonfinite or zero normalization scales;
- records checkpoint path, model type, input layout, output meaning, and units.

## Prediction responsibilities

`predict_tdoa_correction` owns the complete inference transform:

1. validate `N x 110` raw input;
2. apply checkpoint `muX`/`sigmaX` z-score statistics;
3. reshape only when the model requires a CNN image input;
4. call the saved MATLAB network;
5. apply checkpoint `muY`/`sigmaY` output de-normalization;
6. return an `N x 1` prediction in metres.

The active `inference.m`, `inference_tdoa.m`, and
`inference_timesequnce.m` scripts now use this interface. Their feature-window
construction and temporal rollout behavior remain unchanged.

## Deliberate exclusions

The preserved LSTM checkpoint is not routed through this interface. Its input
is a different sequence representation with unresolved cross-flight boundary
and training-provenance problems. Pretending it shares the 110-feature FNN/CNN
contract would be unsafe. Quantized/deployment networks also retain their
specialized path until their tensor and normalization contracts are tested.

## Validation

FNN, CNN1, and CNN2 were each evaluated on two deterministic raw feature rows.
For every model, the shared interface reproduced the former inline
normalization, reshape, prediction, and de-normalization result within
`1e-12`. Invalid feature width raises `model:FeatureShapeMismatch`.

The configuration factory, model loader, and predictor have zero MATLAB Code
Analyzer findings. Seven existing findings remain in the three legacy entry
scripts. The historical baseline remained 21 flights, 336 long-form rows, and
576 summaries with unchanged values.

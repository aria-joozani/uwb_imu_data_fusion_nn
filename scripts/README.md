# MATLAB scripts

Run `setup_project` from the repository root before invoking these scripts.

- `preprocessing/`: raw extraction, synchronization, and supervised dataset generation.
- `training/`: FNN, CNN, and preserved legacy LSTM training experiments.
- `evaluation/`: neural inference, TDoA positioning, ESKF evaluation, and baseline reconstruction.
- `deployment/`: PTQ tensor preparation, quantization, and ONNX export.
- `visualization/`: standalone dataset and thesis-summary plotting.

These are still research scripts with base-workspace dependencies. Their move into
categories does not make them validated APIs; see `docs/code_review.md`.

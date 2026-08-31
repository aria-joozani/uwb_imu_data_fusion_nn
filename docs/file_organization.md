# Categorized File Organization

## Outcome

Tracked research files are organized by responsibility. The move is structural:
scientific formulas, model weights, datasets, and saved baseline values were not
changed. Git rename metadata preserves file history.

## Directory tree

```text
.
|-- setup_project.m
|-- run_project_tests.m
|-- tests/
|-- scripts/
|   |-- preprocessing/
|   |-- training/
|   |-- evaluation/
|   |-- deployment/
|   `-- visualization/
|-- src/
|   |-- data/
|   |-- preprocessing/
|   |-- uwb/
|   |-- localization/
|   |-- eskf/
|   |-- models/
|   |-- evaluation/
|   |-- visualization/
|   `-- utilities/
|-- models/
|   |-- active/
|   `-- legacy/
|-- config/legacy/
|-- artifacts/baseline/
|   |-- source/
|   `-- derived/
|-- assets/diagrams/
|-- tools/diagrams/
|-- docs/
|-- archive/matlab-autosave/
|-- external/unlicensed/       (ignored)
`-- local-artifacts/           (ignored)
```

Raw and generated data directories remain at the repository root because the
legacy scripts and stored experiment provenance use those paths:
`csv-data/`, `export-data-set/`, `export-data-set-r/`, `survey-results/`, and
`result/`.

## Move categories

| Old location | New location | Category |
|---|---|---|
| root extraction/generator scripts | `scripts/preprocessing/` | preprocessing |
| root `train_tdoa_*.m` scripts | `scripts/training/` | model training |
| root inference/fusion scripts | `scripts/evaluation/` | evaluation |
| root PTQ/ONNX scripts | `scripts/deployment/` | deployment |
| root standalone plot scripts | `scripts/visualization/` | visualization |
| root reviewed checkpoints | `models/active/` | active model evidence |
| former `networks/` contents | `models/legacy/` | historical model evidence |
| root `trials.mat` | `config/legacy/` | legacy runner input |
| former `result/*.xlsx` | `artifacts/baseline/source/` | historical baseline source |
| former `results/*.csv` | `artifacts/baseline/derived/` | deterministic baseline output |
| former `diagram/` tracked files | `assets/diagrams/` | thesis diagram assets |
| root diagram generator | `tools/diagrams/` | development tool |
| tracked MATLAB autosave | `archive/matlab-autosave/` | preserved non-active history |
| former flat `library/` functions | `src/<pipeline-stage>/` | reusable stage implementation |

Ignored root plots, logs, archives, workbook copies, PTQ tensors, and the binary
baseline container were moved into `local-artifacts/`. The externally attributed
`ieee.m` file was moved to `external/unlicensed/` pending a license/provenance
decision. These local moves are not included in Git and no files were deleted.

## MATLAB execution contract

Start MATLAB in the repository root and run:

```matlab
projectRoot = setup_project();
```

This adds the nine explicit `src/` pipeline-stage folders and the five
`scripts/` category folders to the MATLAB path. It deliberately does not add
models, artifacts, archives, or local output directories. Legacy scripts still
use base-workspace state and should be invoked from the repository root until
the planned functional refactor is complete.

Model loads and saves now use `models/active/` or `models/legacy/`. Deployment
intermediates use ignored `local-artifacts/intermediates/`. The baseline entry
point reads and writes `artifacts/baseline/`.

## Behavior-preservation boundary

This organization does not fix the leakage, TDoA sign, time alignment, position
MA, or ESKF issues in the review documents. Path changes are validated separately
from scientific corrections so future numerical differences remain attributable.

## Validation

- `setup_project` resolves entry scripts and reusable functions, including
  `src/eskf/ESKF.m`, from their categorized paths.
- MATLAB `checkcode` scanned 50 tracked MATLAB files; 22 known legacy findings
  remain, while `setup_project.m` and `run_baseline_evaluation.m` are clean.
- `run_project_tests` provides the permanent automated validation entry point;
  its current scope and exclusions are recorded in `docs/automated_validation.md`.
- The relocated baseline reproduced 21 flights, 336 long-form rows, 576 grouped
  summaries, and the same headline metrics.
- SHA-256 hashes for all five active checkpoints are unchanged after the move.

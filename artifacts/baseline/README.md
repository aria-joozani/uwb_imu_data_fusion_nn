# Historical baseline artifacts

- `source/` contains the four 21-flight XLSX summaries recovered from the
  historical result tree.
- `derived/` contains deterministic long-form and grouped CSV reconstructions.

Run `setup_project`, load `load_experiment_config("baseline")`, and pass that
configuration to `run_baseline_evaluation` to inspect or regenerate the derived
records. This is an artifact reconstruction, not fresh model inference; see
`docs/baseline_results.md`.

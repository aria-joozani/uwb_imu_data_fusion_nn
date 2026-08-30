function config = baseline_config(repositoryRoot)
%BASELINE_CONFIG Configuration for the historical 21-flight baseline.
%
% config = baseline_config()
% config = baseline_config(repositoryRoot)
%
% The values in this configuration are extracted from the existing baseline
% evaluator and saved artifacts. They preserve legacy behavior; they are not
% newly selected experiment parameters.

    if nargin < 1 || isempty(repositoryRoot)
        repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
    end
    repositoryRoot = char(string(repositoryRoot));

    config = struct();
    config.schemaVersion = 1;
    config.name = 'baseline';
    config.behaviorMode = 'historical_artifact_reconstruction';

    config.paths = struct( ...
        'repositoryRoot', repositoryRoot, ...
        'sourceDir', fullfile(repositoryRoot, 'artifacts', 'baseline', 'source'), ...
        'outputDir', fullfile(repositoryRoot, 'artifacts', 'baseline', 'derived'));

    config.dataset = struct( ...
        'constellation', 'const4', ...
        'expectedFlightCount', 21);

    config.models = struct( ...
        'names', ["raw"; "fnn"; "cnn1"; "cnn2"]);

    config.evaluation = struct();
    config.evaluation.artifacts = {
        'result_overall_tdoa_rms.xlsx', 'tdoa',     'rmse_m';
        'result_overall_tdoa_ma.xlsx',  'tdoa',     'mae_m';
        'result_position_rms.xlsx',      'position', 'rmse_m';
        'result_position_ma.xlsx',       'position', 'mae_m'
    };
    config.evaluation.writeOutput = true;
    config.evaluation.overwrite = false;
    config.evaluation.outputFiles = {
        'baseline_results.csv';
        'baseline_summary.csv';
        'baseline_unavailable_metrics.csv';
        'baseline_results.mat'
    };
end

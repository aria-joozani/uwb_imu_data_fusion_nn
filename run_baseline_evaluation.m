function results = run_baseline_evaluation(config)
%RUN_BASELINE_EVALUATION Reconstruct the documented historical baseline.
%
% results = run_baseline_evaluation()
% results = run_baseline_evaluation(config)
%
% This entry point intentionally reads the existing 21-flight summary
% spreadsheets. It does not rerun inference, retrain a network, or alter the
% historical algorithms. The source artifacts contain per-flight TDoA RMSE,
% TDoA MAE, and position RMSE. Position MAE is present as an all-NaN sheet;
% signed mean error and sample-level distribution statistics cannot be
% reconstructed from the saved summaries.
%
% Optional config fields:
%   sourceDir   Directory containing the historical XLSX files.
%   outputDir   Directory for machine-readable reconstructed results.
%   writeOutput Write CSV and MAT outputs (default true).
%   overwrite   Permit replacement of existing generated outputs (default false).

    if nargin < 1
        config = struct();
    end
    validateattributes(config, {'struct'}, {'scalar'}, mfilename, 'config');

    repositoryRoot = fileparts(mfilename('fullpath'));
    config = applyDefaults(config, repositoryRoot);

    specs = {
        'result_overall_tdoa_rms.xlsx', 'tdoa',     'rmse_m';
        'result_overall_tdoa_ma.xlsx',  'tdoa',     'mae_m';
        'result_position_rms.xlsx',      'position', 'rmse_m';
        'result_position_ma.xlsx',       'position', 'mae_m'
    };

    perFlight = table();
    referenceLabels = strings(0, 1);
    for i = 1:size(specs, 1)
        artifactPath = fullfile(config.sourceDir, specs{i, 1});
        if ~isfile(artifactPath)
            error('baseline:MissingArtifact', ...
                'Required historical baseline artifact not found: %s', artifactPath);
        end

        [artifactRows, labels] = readMetricArtifact( ...
            artifactPath, specs{i, 2}, specs{i, 3});
        if isempty(referenceLabels)
            referenceLabels = labels;
        elseif ~isequal(referenceLabels, labels)
            error('baseline:FlightOrderMismatch', ...
                'Flight labels/order differ in %s.', artifactPath);
        end
        perFlight = [perFlight; artifactRows]; %#ok<AGROW>
    end

    expectedFlightCount = 21;
    actualFlights = unique(perFlight.Flight, 'stable');
    if numel(actualFlights) ~= expectedFlightCount
        error('baseline:UnexpectedFlightCount', ...
            'Expected %d flights but found %d.', expectedFlightCount, numel(actualFlights));
    end

    summary = summarizeFlightMetrics(perFlight);
    unavailableMetrics = table( ...
        ["tdoa"; "position"; "position"; "position"], ...
        ["mean_error_m"; "mean_error_m"; "std_error_m"; "max_and_percentile_error_m"], ...
        ["not stored in historical artifacts"; ...
         "not stored in historical artifacts"; ...
         "sample-level errors not stored in a machine-readable artifact"; ...
         "sample-level errors not stored in a machine-readable artifact"], ...
        'VariableNames', {'Task', 'Metric', 'Reason'});

    metadata = struct();
    metadata.baselineType = 'historical_artifact_reconstruction';
    metadata.repositoryRoot = repositoryRoot;
    metadata.sourceDir = config.sourceDir;
    metadata.generatedAt = char(datetime('now', 'TimeZone', 'local', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
    metadata.randomSeed = 'NOT_APPLICABLE_FOR_DETERMINISTIC_AGGREGATION';
    metadata.originalTrainingSeed = 'UNKNOWN';
    metadata.flightCount = numel(actualFlights);
    metadata.constellations = cellstr(unique(perFlight.Constellation, 'stable'));
    metadata.models = cellstr(unique(perFlight.Model, 'stable'));
    metadata.limitations = [ ...
        "This run reconstructs existing XLSX summaries; it is not live model inference."; ...
        "Position MAE source values are all NaN."; ...
        "Signed mean, sample standard deviation, maxima, and sample percentiles are unavailable."; ...
        "Training/evaluation overlap and inference alignment risks remain in the historical results." ...
    ];

    results = struct();
    results.metadata = metadata;
    results.perFlight = perFlight;
    results.summary = summary;
    results.unavailableMetrics = unavailableMetrics;

    if config.writeOutput
        writeResults(results, config);
    end

    printHeadline(summary);
end

function config = applyDefaults(config, repositoryRoot)
    defaults = struct( ...
        'sourceDir', fullfile(repositoryRoot, 'result'), ...
        'outputDir', fullfile(repositoryRoot, 'results'), ...
        'writeOutput', true, ...
        'overwrite', false);

    names = fieldnames(defaults);
    for i = 1:numel(names)
        name = names{i};
        if ~isfield(config, name) || isempty(config.(name))
            config.(name) = defaults.(name);
        end
    end

    config.sourceDir = char(string(config.sourceDir));
    config.outputDir = char(string(config.outputDir));
    validateattributes(config.writeOutput, {'logical', 'numeric'}, {'scalar'});
    validateattributes(config.overwrite, {'logical', 'numeric'}, {'scalar'});
    config.writeOutput = logical(config.writeOutput);
    config.overwrite = logical(config.overwrite);
end

function [rows, labels] = readMetricArtifact(artifactPath, task, metric)
    imported = readtable(artifactPath, 'VariableNamingRule', 'preserve');
    if width(imported) ~= 5
        error('baseline:UnexpectedArtifactShape', ...
            'Expected five columns in %s, found %d.', artifactPath, width(imported));
    end

    labels = strtrim(string(imported{:, 1}));
    values = imported{:, 2:5};
    if ~isnumeric(values)
        error('baseline:NonNumericMetric', ...
            'Metric columns in %s are not numeric.', artifactPath);
    end

    models = ["raw"; "fnn"; "cnn1"; "cnn2"];
    nFlights = numel(labels);
    nModels = numel(models);
    if size(values, 1) ~= nFlights || size(values, 2) ~= nModels
        error('baseline:UnexpectedMetricShape', ...
            'Unexpected metric matrix shape in %s.', artifactPath);
    end

    trial = strings(nFlights, 1);
    trajectory = strings(nFlights, 1);
    for i = 1:nFlights
        token = regexp(labels(i), '^(trial\d+)-(.+)$', 'tokens', 'once');
        if isempty(token)
            error('baseline:InvalidFlightLabel', ...
                'Cannot parse flight label "%s" in %s.', labels(i), artifactPath);
        end
        trial(i) = string(token{1});
        trajectory(i) = string(token{2});
    end

    valueVector = reshape(values.', [], 1);
    status = repmat("available", numel(valueVector), 1);
    status(isnan(valueVector)) = "unavailable_in_source";

    rows = table( ...
        repelem("const4-" + labels, nModels), ...
        repelem(repmat("const4", nFlights, 1), nModels), ...
        repelem(trial, nModels), ...
        repelem(trajectory, nModels), ...
        repmat(models, nFlights, 1), ...
        repmat(string(task), nFlights * nModels, 1), ...
        repmat(string(metric), nFlights * nModels, 1), ...
        valueVector, ...
        repmat("m", nFlights * nModels, 1), ...
        status, ...
        repmat(string(artifactPath), nFlights * nModels, 1), ...
        'VariableNames', {'Flight', 'Constellation', 'Trial', 'Trajectory', ...
        'Model', 'Task', 'Metric', 'Value', 'Unit', 'Status', 'SourceArtifact'});
end

function summary = summarizeFlightMetrics(perFlight)
    levels = ["flight", "trial", "trajectory", "constellation", "overall"];
    groupVectors = {perFlight.Flight, perFlight.Trial, perFlight.Trajectory, ...
        perFlight.Constellation, repmat("all", height(perFlight), 1)};
    combinations = unique(perFlight(:, {'Task', 'Model', 'Metric', 'Unit'}), ...
        'rows', 'stable');

    levelOut = strings(0, 1);
    groupOut = strings(0, 1);
    taskOut = strings(0, 1);
    modelOut = strings(0, 1);
    metricOut = strings(0, 1);
    unitOut = strings(0, 1);
    availableOut = zeros(0, 1);
    missingOut = zeros(0, 1);
    meanOut = zeros(0, 1);
    stdOut = zeros(0, 1);
    minOut = zeros(0, 1);
    maxOut = zeros(0, 1);
    p50Out = zeros(0, 1);
    p90Out = zeros(0, 1);
    p95Out = zeros(0, 1);
    statusOut = strings(0, 1);

    for levelIndex = 1:numel(levels)
        groups = unique(groupVectors{levelIndex}, 'stable');
        for groupIndex = 1:numel(groups)
            groupMask = groupVectors{levelIndex} == groups(groupIndex);
            for comboIndex = 1:height(combinations)
                combo = combinations(comboIndex, :);
                mask = groupMask & ...
                    perFlight.Task == combo.Task & ...
                    perFlight.Model == combo.Model & ...
                    perFlight.Metric == combo.Metric;
                if ~any(mask)
                    continue;
                end

                candidateValues = perFlight.Value(mask);
                values = candidateValues(isfinite(candidateValues));
                available = numel(values);
                missing = numel(candidateValues) - available;

                levelOut(end + 1, 1) = levels(levelIndex); %#ok<AGROW>
                groupOut(end + 1, 1) = groups(groupIndex); %#ok<AGROW>
                taskOut(end + 1, 1) = combo.Task; %#ok<AGROW>
                modelOut(end + 1, 1) = combo.Model; %#ok<AGROW>
                metricOut(end + 1, 1) = combo.Metric; %#ok<AGROW>
                unitOut(end + 1, 1) = combo.Unit; %#ok<AGROW>
                availableOut(end + 1, 1) = available; %#ok<AGROW>
                missingOut(end + 1, 1) = missing; %#ok<AGROW>

                if isempty(values)
                    meanOut(end + 1, 1) = NaN; %#ok<AGROW>
                    stdOut(end + 1, 1) = NaN; %#ok<AGROW>
                    minOut(end + 1, 1) = NaN; %#ok<AGROW>
                    maxOut(end + 1, 1) = NaN; %#ok<AGROW>
                    p50Out(end + 1, 1) = NaN; %#ok<AGROW>
                    p90Out(end + 1, 1) = NaN; %#ok<AGROW>
                    p95Out(end + 1, 1) = NaN; %#ok<AGROW>
                    statusOut(end + 1, 1) = "unavailable"; %#ok<AGROW>
                else
                    meanOut(end + 1, 1) = mean(values); %#ok<AGROW>
                    stdOut(end + 1, 1) = std(values, 0); %#ok<AGROW>
                    minOut(end + 1, 1) = min(values); %#ok<AGROW>
                    maxOut(end + 1, 1) = max(values); %#ok<AGROW>
                    p50Out(end + 1, 1) = linearPercentile(values, 0.50); %#ok<AGROW>
                    p90Out(end + 1, 1) = linearPercentile(values, 0.90); %#ok<AGROW>
                    p95Out(end + 1, 1) = linearPercentile(values, 0.95); %#ok<AGROW>
                    if missing == 0
                        statusOut(end + 1, 1) = "available"; %#ok<AGROW>
                    else
                        statusOut(end + 1, 1) = "partial"; %#ok<AGROW>
                    end
                end
            end
        end
    end

    summary = table(levelOut, groupOut, taskOut, modelOut, metricOut, unitOut, ...
        availableOut, missingOut, meanOut, stdOut, minOut, maxOut, ...
        p50Out, p90Out, p95Out, statusOut, ...
        'VariableNames', {'Level', 'Group', 'Task', 'Model', 'Metric', 'Unit', ...
        'AvailableFlightCount', 'MissingFlightCount', 'MeanOfFlightMetric', ...
        'StdOfFlightMetric', 'MinFlightMetric', 'MaxFlightMetric', ...
        'P50FlightMetric', 'P90FlightMetric', 'P95FlightMetric', 'Status'});
end

function value = linearPercentile(values, probability)
    values = sort(values(:));
    if isscalar(values)
        value = values(1);
        return;
    end
    position = 1 + (numel(values) - 1) * probability;
    lowerIndex = floor(position);
    upperIndex = ceil(position);
    fraction = position - lowerIndex;
    value = values(lowerIndex) + fraction * ...
        (values(upperIndex) - values(lowerIndex));
end

function writeResults(results, config)
    if ~isfolder(config.outputDir)
        mkdir(config.outputDir);
    end

    outputFiles = {
        fullfile(config.outputDir, 'baseline_results.csv');
        fullfile(config.outputDir, 'baseline_summary.csv');
        fullfile(config.outputDir, 'baseline_unavailable_metrics.csv');
        fullfile(config.outputDir, 'baseline_results.mat')
    };
    if ~config.overwrite
        existing = outputFiles(cellfun(@isfile, outputFiles));
        if ~isempty(existing)
            error('baseline:OutputExists', ...
                'Refusing to overwrite generated baseline output: %s', existing{1});
        end
    end

    writetable(results.perFlight, outputFiles{1});
    writetable(results.summary, outputFiles{2});
    writetable(results.unavailableMetrics, outputFiles{3});
    save(outputFiles{4}, 'results');
end

function printHeadline(summary)
    headline = summary(summary.Level == "overall" & ...
        summary.Group == "all" & summary.Status == "available", :);
    fprintf('\nHistorical baseline reconstructed from saved 21-flight artifacts.\n');
    fprintf('Values below are means of per-flight metrics, not pooled sample errors.\n\n');
    for i = 1:height(headline)
        fprintf('%-8s %-8s %-7s mean=%0.6f m, std=%0.6f m, max=%0.6f m, p95=%0.6f m\n', ...
            headline.Task(i), headline.Model(i), headline.Metric(i), ...
            headline.MeanOfFlightMetric(i), headline.StdOfFlightMetric(i), ...
            headline.MaxFlightMetric(i), headline.P95FlightMetric(i));
    end
end

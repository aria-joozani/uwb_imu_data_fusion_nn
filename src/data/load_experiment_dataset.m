function dataset = load_experiment_dataset(config)
%LOAD_EXPERIMENT_DATASET Load one raw flight and its anchor survey.
%
% dataset = load_experiment_dataset(config)
%
% Required configuration:
%   config.dataset.csvFile       Raw sparse flight CSV.
%   config.dataset.anchorFile    Processed anchor survey text file.
%
% Optional configuration:
%   config.dataset.includeRawTable  Retain the imported table (default true).
%
% Output units and dimensions:
%   dataset.imu.accelerometer    Na x 4 [s, g, g, g]
%   dataset.imu.gyroscope        Ng x 4 [s, deg/s, deg/s, deg/s]
%   dataset.uwb.tdoa             Nu x 4 [s, idA, idB, m]
%   dataset.groundTruth.pose     Nv x 8 [s, m, m, m, qx, qy, qz, qw]
%   dataset.anchors.positions    8 x 3 [m], local survey frame
%   dataset.anchors.quaternions  8 x 4 [qx, qy, qz, qw]
%
% This function reproduces the former loading portion of data_extractor.m.
% It does not synchronize, shift timestamps, downsample, filter anchor
% pairs, interpolate ground truth, or generate ideal TDoA values.

    validateattributes(config, {'struct'}, {'scalar'}, mfilename, 'config');
    if ~isfield(config, 'dataset') || ~isstruct(config.dataset) || ...
            ~isscalar(config.dataset)
        error('dataset:MissingConfiguration', ...
            'config.dataset must be a scalar structure.');
    end

    csvFile = requirePath(config.dataset, 'csvFile');
    anchorFile = requirePath(config.dataset, 'anchorFile');
    includeRawTable = getOptionalLogical(config.dataset, ...
        'includeRawTable', true);

    if ~isfile(csvFile)
        error('dataset:MissingFlightFile', ...
            'Raw flight CSV not found: %s', csvFile);
    end
    if ~isfile(anchorFile)
        error('dataset:MissingAnchorFile', ...
            'Anchor survey file not found: %s', anchorFile);
    end

    rawTable = readtable(csvFile);
    requiredVariables = [ ...
        "t_tdoa", "idA", "idB", "tdoa_meas", ...
        "t_acc", "acc_x", "acc_y", "acc_z", ...
        "t_gyro", "gyro_x", "gyro_y", "gyro_z", ...
        "t_pose", "pose_x", "pose_y", "pose_z", ...
        "pose_qx", "pose_qy", "pose_qz", "pose_qw"];
    missingVariables = setdiff(requiredVariables, ...
        string(rawTable.Properties.VariableNames), 'stable');
    if ~isempty(missingVariables)
        error('dataset:MissingVariables', ...
            'Raw flight table is missing required variables: %s', ...
            strjoin(missingVariables, ', '));
    end

    tdoa = extract_tdoa(rawTable);
    accelerometer = extract_acc(rawTable);
    gyroscope = extract_gyro(rawTable);
    groundTruthPose = extract_gt(rawTable);
    anchors = readAnchorSurvey(anchorFile);

    [~, flightName] = fileparts(csvFile);
    [~, constellationName] = fileparts(anchorFile);

    dataset = struct();
    if includeRawTable
        dataset.rawTable = rawTable;
    else
        dataset.rawTable = table();
    end
    dataset.timestamps = struct( ...
        'tdoa', tdoa(:, 1), ...
        'accelerometer', accelerometer(:, 1), ...
        'gyroscope', gyroscope(:, 1), ...
        'groundTruth', groundTruthPose(:, 1));
    dataset.uwb = struct('tdoa', tdoa);
    dataset.imu = struct( ...
        'accelerometer', accelerometer, ...
        'gyroscope', gyroscope);
    dataset.groundTruth = struct('pose', groundTruthPose);
    dataset.anchors = anchors;

    dataset.metadata = struct();
    dataset.metadata.flightFile = csvFile;
    dataset.metadata.anchorFile = anchorFile;
    dataset.metadata.flightName = flightName;
    dataset.metadata.constellationName = constellationName;
    dataset.metadata.rawRowCount = height(rawTable);
    dataset.metadata.streamSampleCounts = struct( ...
        'tdoa', size(tdoa, 1), ...
        'accelerometer', size(accelerometer, 1), ...
        'gyroscope', size(gyroscope, 1), ...
        'groundTruth', size(groundTruthPose, 1));
    dataset.metadata.units = struct( ...
        'time', 's', ...
        'position', 'm', ...
        'tdoaRangeDifference', 'm', ...
        'accelerometer', 'g', ...
        'gyroscope', 'deg/s', ...
        'anchorPosition', 'm', ...
        'anchorQuaternionOrder', 'qx_qy_qz_qw');
    dataset.metadata.coordinateFrame = ...
        'LOCAL_SURVEY_FRAME_EXACT_ORIENTATION_UNKNOWN';
end

function value = requirePath(datasetConfig, fieldName)
    if ~isfield(datasetConfig, fieldName) || isempty(datasetConfig.(fieldName))
        error('dataset:MissingConfiguration', ...
            'config.dataset.%s is required.', fieldName);
    end
    validateattributes(datasetConfig.(fieldName), {'char', 'string'}, ...
        {'scalartext'}, mfilename, ['config.dataset.' fieldName]);
    value = char(string(datasetConfig.(fieldName)));
end

function value = getOptionalLogical(datasetConfig, fieldName, defaultValue)
    if ~isfield(datasetConfig, fieldName) || isempty(datasetConfig.(fieldName))
        value = defaultValue;
        return;
    end
    validateattributes(datasetConfig.(fieldName), {'logical', 'numeric'}, ...
        {'scalar'}, mfilename, ['config.dataset.' fieldName]);
    value = logical(datasetConfig.(fieldName));
end

function anchors = readAnchorSurvey(anchorFile)
    lines = splitlines(fileread(anchorFile));
    lines(cellfun(@isempty, lines)) = [];

    positions = NaN(8, 3);
    quaternions = NaN(8, 4);
    names = strings(8, 1);

    for i = 1:numel(lines)
        parts = strsplit(lines{i}, ',');
        name = parts{1};
        values = str2double(parts(2:end));
        indexToken = extractBetween(name, 3, 3);
        anchorIndex = str2double(indexToken) + 1;
        if ~isfinite(anchorIndex) || anchorIndex < 1 || anchorIndex > 8
            error('dataset:InvalidAnchorName', ...
                'Cannot determine anchor index from "%s" in %s.', ...
                name, anchorFile);
        end

        if contains(name, '_p')
            if numel(values) ~= 3
                error('dataset:InvalidAnchorPosition', ...
                    'Expected three position values for %s.', name);
            end
            positions(anchorIndex, :) = values;
            names(anchorIndex) = string(name(1:3));
        elseif contains(name, '_quat')
            if numel(values) ~= 4
                error('dataset:InvalidAnchorQuaternion', ...
                    'Expected four quaternion values for %s.', name);
            end
            quaternions(anchorIndex, :) = values;
        end
    end

    if any(~isfinite(positions), 'all') || any(~isfinite(quaternions), 'all')
        error('dataset:IncompleteAnchorSurvey', ...
            ['Anchor survey must define positions and quaternions for ' ...
             'anchors 0-7: %s'], anchorFile);
    end

    anchors = struct( ...
        'positions', positions, ...
        'quaternions', quaternions, ...
        'names', names, ...
        'positionUnits', 'm', ...
        'quaternionOrder', 'qx_qy_qz_qw', ...
        'coordinateFrame', 'LOCAL_SURVEY_FRAME_EXACT_ORIENTATION_UNKNOWN');
end

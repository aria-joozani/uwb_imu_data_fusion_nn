function processed = preprocess_sensor_data(synchronized, config)
%PREPROCESS_SENSOR_DATA Apply legacy rate, pair, and label processing.
%
% processed = preprocess_sensor_data(synchronized, config)
%
% Inputs:
%   synchronized  Output from synchronize_sensor_data.
%   config        Legacy preprocessing configuration.
%
% Outputs:
%   processed.timestamps.imu          Ni x 1 [s]
%   processed.imu.samples             Ni x 6 [g, deg/s]
%   processed.uwb.tdoaAll             M x 4 [s, idA, idB, m]
%   processed.uwb.measurements        M x 3 [idA, idB, m]
%   processed.groundTruth.atUwb       M x 4 [s, x, y, z] [s,m]
%   processed.uwb.idealTdoa           M x 4 [s, idA, idB, m]
%
% The function preserves factor-8 first-sample downsampling per stream and
% per configured anchor pair, followed by timestamp sorting and spline
% ground-truth interpolation. It does not build neural feature windows.

    validateSynchronized(synchronized);
    preprocessing = requirePreprocessingConfig(config);
    validatePreprocessingConfig(preprocessing);

    factor = preprocessing.downsampleFactor;
    imuTime = selectFirstEvery(synchronized.timestamps.imu, factor);
    imuSamples = selectFirstEvery(synchronized.imu.samples, factor);

    shiftedTdoa = synchronized.uwb.tdoa;
    anchorPairs = preprocessing.anchorPairs;
    pairBlocks = cell(size(anchorPairs, 1), 1);
    for pairIndex = 1:size(anchorPairs, 1)
        pair = anchorPairs(pairIndex, :);
        pairMask = shiftedTdoa(:, 2) == pair(1) & ...
            shiftedTdoa(:, 3) == pair(2);
        pairBlocks{pairIndex} = selectFirstEvery( ...
            shiftedTdoa(pairMask, :), factor);
    end
    tdoaAll = sortrows(vertcat(pairBlocks{:}), 1);
    uwbTime = tdoaAll(:, 1);

    groundTruthTime = synchronized.timestamps.groundTruth;
    groundTruthPosition = synchronized.groundTruth.position;
    positionAtUwb = zeros(numel(uwbTime), 3);
    for axis = 1:3
        positionAtUwb(:, axis) = interp1( ...
            groundTruthTime, groundTruthPosition(:, axis), uwbTime, ...
            preprocessing.groundTruthInterpolationMethod);
    end
    groundTruthAtUwb = [uwbTime, positionAtUwb];

    if preprocessing.generateIdealTdoa
        idealTdoa = simulate_tdoa_sequence_from_gt( ...
            groundTruthAtUwb, tdoaAll(:, 1:3), ...
            synchronized.anchors.positions);
    else
        idealTdoa = zeros(0, 4);
    end

    processed = struct();
    processed.timestamps = struct( ...
        'imu', imuTime, ...
        'uwb', uwbTime, ...
        'groundTruth', groundTruthTime, ...
        'idealTdoa', idealTdoa(:, 1));
    processed.imu = struct( ...
        'samples', imuSamples, ...
        'accelerometerUnits', synchronized.imu.accelerometerUnits, ...
        'gyroscopeUnits', synchronized.imu.gyroscopeUnits);
    processed.uwb = struct( ...
        'tdoaAll', tdoaAll, ...
        'measurements', tdoaAll(:, 2:4), ...
        'idealTdoa', idealTdoa, ...
        'idealMeasurements', idealTdoa(:, 2:4), ...
        'measurementUnits', 'm');
    processed.groundTruth = struct( ...
        'time', groundTruthTime, ...
        'position', groundTruthPosition, ...
        'atUwb', groundTruthAtUwb, ...
        'positionUnits', 'm');
    processed.anchors = synchronized.anchors;
    processed.metadata = synchronized.metadata;
    processed.metadata.downsampleFactor = factor;
    processed.metadata.anchorPairs = anchorPairs;
    processed.metadata.groundTruthInterpolationMethod = ...
        preprocessing.groundTruthInterpolationMethod;
    processed.metadata.generateIdealTdoa = preprocessing.generateIdealTdoa;
    processed.metadata.sampleCounts = struct( ...
        'imu', size(imuSamples, 1), ...
        'uwb', size(tdoaAll, 1), ...
        'groundTruth', size(groundTruthPosition, 1));
end

function output = selectFirstEvery(input, factor)
    output = input(1:factor:end, :);
end

function validateSynchronized(synchronized)
    validateattributes(synchronized, {'struct'}, {'scalar'}, ...
        mfilename, 'synchronized');
    required = {'timestamps', 'imu', 'uwb', 'groundTruth', 'anchors', 'metadata'};
    for i = 1:numel(required)
        if ~isfield(synchronized, required{i})
            error('preprocessing:InvalidSynchronizedData', ...
                'Synchronized data is missing field "%s".', required{i});
        end
    end
end

function preprocessing = requirePreprocessingConfig(config)
    validateattributes(config, {'struct'}, {'scalar'}, mfilename, 'config');
    if ~isfield(config, 'preprocessing') || ...
            ~isstruct(config.preprocessing) || ~isscalar(config.preprocessing)
        error('preprocessing:MissingConfiguration', ...
            'config.preprocessing must be a scalar structure.');
    end
    preprocessing = config.preprocessing;
end

function validatePreprocessingConfig(preprocessing)
    required = {'downsampleFactor', 'anchorPairs', ...
        'groundTruthInterpolationMethod', 'generateIdealTdoa'};
    for i = 1:numel(required)
        if ~isfield(preprocessing, required{i})
            error('preprocessing:MissingConfiguration', ...
                'config.preprocessing.%s is required.', required{i});
        end
    end
    validateattributes(preprocessing.downsampleFactor, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});
    validateattributes(preprocessing.anchorPairs, {'numeric'}, ...
        {'2d', 'ncols', 2, 'integer', '>=', 0, '<=', 7});
    if string(preprocessing.groundTruthInterpolationMethod) ~= "spline"
        error('preprocessing:UnsupportedGroundTruthInterpolation', ...
            'Only the validated legacy spline interpolation is supported.');
    end
    validateattributes(preprocessing.generateIdealTdoa, ...
        {'logical', 'numeric'}, {'scalar'});
end

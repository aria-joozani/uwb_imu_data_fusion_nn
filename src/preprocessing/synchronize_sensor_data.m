function synchronized = synchronize_sensor_data(dataset, config)
%SYNCHRONIZE_SENSOR_DATA Align active raw streams to the legacy time basis.
%
% synchronized = synchronize_sensor_data(dataset, config)
%
% Inputs:
%   dataset  Output from load_experiment_dataset.
%   config   Experiment config with config.preprocessing fields.
%
% Outputs:
%   synchronized.timestamps.imu          Na x 1 [s]
%   synchronized.imu.samples             Na x 6 [g, deg/s]
%   synchronized.uwb.tdoa                Nu x 4 [s, idA, idB, m]
%   synchronized.timestamps.groundTruth  Nv2 x 1 [s]
%   synchronized.groundTruth.position    Nv2 x 3 [m]
%
% Gyroscope values are linearly interpolated/extrapolated to accelerometer
% timestamps. Active timestamps are shifted by the minimum of the first
% TDoA, accelerometer, and ground-truth timestamps. Ground truth retains only
% samples strictly after that origin, matching the reviewed legacy behavior.

    validateDataset(dataset);
    preprocessing = requirePreprocessingConfig(config);
    validateLegacySynchronizationConfig(preprocessing);

    accelerometer = dataset.imu.accelerometer;
    gyroscope = dataset.imu.gyroscope;
    tdoa = dataset.uwb.tdoa;
    groundTruthPose = dataset.groundTruth.pose;

    imuTime = accelerometer(:, 1);
    synchronizedGyroscope = zeros(size(accelerometer, 1), 3);
    for axis = 1:3
        synchronizedGyroscope(:, axis) = interp_meas( ...
            gyroscope(:, 1), gyroscope(:, axis + 1), imuTime);
    end
    imuSamples = [accelerometer(:, 2:4), synchronizedGyroscope];

    groundTruthTime = groundTruthPose(:, 1);
    commonTimeOrigin = min([tdoa(1, 1), imuTime(1), groundTruthTime(1)]);
    groundTruthMask = groundTruthTime > commonTimeOrigin;

    synchronized = struct();
    synchronized.timestamps = struct( ...
        'imu', imuTime - commonTimeOrigin, ...
        'groundTruth', groundTruthTime(groundTruthMask) - commonTimeOrigin);
    synchronized.imu = struct( ...
        'samples', imuSamples, ...
        'accelerometerUnits', 'g', ...
        'gyroscopeUnits', 'deg/s');
    tdoa(:, 1) = tdoa(:, 1) - commonTimeOrigin;
    synchronized.uwb = struct('tdoa', tdoa);
    synchronized.groundTruth = struct( ...
        'position', groundTruthPose(groundTruthMask, 2:4), ...
        'positionUnits', 'm');
    synchronized.anchors = dataset.anchors;
    synchronized.metadata = dataset.metadata;
    synchronized.metadata.commonTimeOrigin = commonTimeOrigin;
    synchronized.metadata.gyroscopeInterpolationMethod = ...
        preprocessing.gyroscopeInterpolationMethod;
    synchronized.metadata.gyroscopeExtrapolation = ...
        preprocessing.gyroscopeExtrapolation;
    synchronized.metadata.groundTruthStartRule = ...
        preprocessing.groundTruthStartRule;
end

function validateDataset(dataset)
    validateattributes(dataset, {'struct'}, {'scalar'}, mfilename, 'dataset');
    required = {'imu', 'uwb', 'groundTruth', 'anchors', 'metadata'};
    for i = 1:numel(required)
        if ~isfield(dataset, required{i})
            error('preprocessing:InvalidDataset', ...
                'Dataset is missing field "%s".', required{i});
        end
    end
    if isempty(dataset.imu.accelerometer) || isempty(dataset.imu.gyroscope) || ...
            isempty(dataset.uwb.tdoa) || isempty(dataset.groundTruth.pose)
        error('preprocessing:EmptyActiveStream', ...
            'Accelerometer, gyroscope, TDoA, and ground truth must be non-empty.');
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

function validateLegacySynchronizationConfig(preprocessing)
    required = {'gyroscopeInterpolationMethod', 'gyroscopeExtrapolation', ...
        'commonTimeOrigin', 'groundTruthStartRule'};
    for i = 1:numel(required)
        if ~isfield(preprocessing, required{i})
            error('preprocessing:MissingConfiguration', ...
                'config.preprocessing.%s is required.', required{i});
        end
    end
    if string(preprocessing.gyroscopeInterpolationMethod) ~= "linear" || ...
            ~logical(preprocessing.gyroscopeExtrapolation) || ...
            string(preprocessing.commonTimeOrigin) ~= ...
                "minimum_first_active_timestamp" || ...
            string(preprocessing.groundTruthStartRule) ~= ...
                "strictly_after_origin"
        error('preprocessing:UnsupportedSynchronizationMode', ...
            'Only the validated legacy synchronization mode is currently supported.');
    end
end

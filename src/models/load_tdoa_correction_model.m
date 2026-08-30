function model = load_tdoa_correction_model(config)
%LOAD_TDOA_CORRECTION_MODEL Load a reviewed neural TDoA checkpoint.
%
% model = load_tdoa_correction_model(config)
%
% Required config.model fields:
%   type, checkpointFile, inputFeatureCount, inputLayout,
%   normalization, outputMeaning, outputUnits
%
% The checkpoint must contain net, muX, sigmaX, muY, and sigmaY. The loaded
% model predicts an ideal/corrected scalar TDoA range difference in metres;
% it does not predict position or position error.

    validateattributes(config, {'struct'}, {'scalar'}, mfilename, 'config');
    if ~isfield(config, 'model') || ~isstruct(config.model) || ...
            ~isscalar(config.model)
        error('model:MissingConfiguration', ...
            'config.model must be a scalar structure.');
    end
    modelConfig = config.model;
    requiredConfig = {'type', 'checkpointFile', 'inputFeatureCount', ...
        'inputLayout', 'normalization', 'outputMeaning', 'outputUnits'};
    for i = 1:numel(requiredConfig)
        if ~isfield(modelConfig, requiredConfig{i})
            error('model:MissingConfiguration', ...
                'config.model.%s is required.', requiredConfig{i});
        end
    end

    checkpointFile = char(string(modelConfig.checkpointFile));
    if ~isfile(checkpointFile)
        error('model:MissingCheckpoint', ...
            'TDoA correction checkpoint not found: %s', checkpointFile);
    end

    checkpoint = load(checkpointFile);
    requiredVariables = {'net', 'muX', 'sigmaX', 'muY', 'sigmaY'};
    for i = 1:numel(requiredVariables)
        if ~isfield(checkpoint, requiredVariables{i})
            error('model:InvalidCheckpoint', ...
                'Checkpoint %s is missing variable "%s".', ...
                checkpointFile, requiredVariables{i});
        end
    end

    featureCount = modelConfig.inputFeatureCount;
    validateattributes(featureCount, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});
    muX = reshape(checkpoint.muX, 1, []);
    sigmaX = reshape(checkpoint.sigmaX, 1, []);
    if numel(muX) ~= featureCount || numel(sigmaX) ~= featureCount
        error('model:NormalizationShapeMismatch', ...
            'Expected %d input statistics but checkpoint contains %d/%d.', ...
            featureCount, numel(muX), numel(sigmaX));
    end
    if any(~isfinite(muX)) || any(~isfinite(sigmaX)) || any(sigmaX == 0)
        error('model:InvalidNormalization', ...
            'Input normalization must be finite with nonzero standard deviations.');
    end
    validateattributes(checkpoint.muY, {'numeric'}, {'scalar', 'finite'});
    validateattributes(checkpoint.sigmaY, {'numeric'}, ...
        {'scalar', 'finite', 'nonzero'});

    supportedLayouts = ["feature_rows", "feature_image_110x1"];
    if ~ismember(string(modelConfig.inputLayout), supportedLayouts)
        error('model:UnsupportedInputLayout', ...
            'Unsupported model input layout "%s".', modelConfig.inputLayout);
    end
    if string(modelConfig.normalization) ~= "checkpoint_zscore"
        error('model:UnsupportedNormalization', ...
            'Unsupported normalization mode "%s".', modelConfig.normalization);
    end

    model = struct();
    model.type = char(string(modelConfig.type));
    model.checkpointFile = checkpointFile;
    model.network = checkpoint.net;
    model.inputFeatureCount = featureCount;
    model.inputLayout = char(string(modelConfig.inputLayout));
    model.normalization = struct( ...
        'muX', muX, ...
        'sigmaX', sigmaX, ...
        'muY', double(checkpoint.muY), ...
        'sigmaY', double(checkpoint.sigmaY));
    model.outputMeaning = char(string(modelConfig.outputMeaning));
    model.outputUnits = char(string(modelConfig.outputUnits));
end

function config = tdoa_model_config(modelType, repositoryRoot)
%TDOA_MODEL_CONFIG Return configuration for a reviewed active checkpoint.
%
% config = tdoa_model_config("fnn")
% config = tdoa_model_config("cnn1", repositoryRoot)
%
% Supported model types are fnn/fcc1, cnn1, cnn2, and cnn3. All mappings
% point to existing reviewed checkpoints; this function does not train or
% select a model based on evaluation results.

    if nargin < 1 || isempty(modelType)
        modelType = "fnn";
    end
    if nargin < 2 || isempty(repositoryRoot)
        repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
    end
    validateattributes(modelType, {'char', 'string'}, {'scalartext'}, ...
        mfilename, 'modelType');
    repositoryRoot = char(string(repositoryRoot));

    canonicalType = lower(string(modelType));
    switch canonicalType
        case {"fnn", "fcc1"}
            canonicalType = "fnn";
            checkpointName = 'trained_tdoa_net_fcc1.mat';
            inputLayout = 'feature_rows';
        case "cnn1"
            checkpointName = 'trained_tdoa_net_cnn_1.mat';
            inputLayout = 'feature_image_110x1';
        case "cnn2"
            checkpointName = 'trained_tdoa_net_cnn_2.mat';
            inputLayout = 'feature_image_110x1';
        case "cnn3"
            checkpointName = 'trained_tdoa_net_cnn_3.mat';
            inputLayout = 'feature_image_110x1';
        otherwise
            error('model:UnknownType', ...
                'Unsupported TDoA correction model type "%s".', modelType);
    end

    config = struct();
    config.schemaVersion = 1;
    config.name = char(canonicalType + "_tdoa_correction");
    config.model = struct( ...
        'type', char(canonicalType), ...
        'checkpointFile', fullfile(repositoryRoot, 'models', 'active', ...
            checkpointName), ...
        'inputFeatureCount', 110, ...
        'inputLayout', inputLayout, ...
        'normalization', 'checkpoint_zscore', ...
        'outputMeaning', 'ideal_tdoa_range_difference', ...
        'outputUnits', 'm');
end

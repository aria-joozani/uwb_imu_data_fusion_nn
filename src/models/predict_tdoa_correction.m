function prediction = predict_tdoa_correction(model, rawFeatures)
%PREDICT_TDOA_CORRECTION Predict ideal TDoA from unnormalized features.
%
% prediction = predict_tdoa_correction(model, rawFeatures)
%
% Inputs:
%   model        Output from load_tdoa_correction_model.
%   rawFeatures  N x 110 numeric matrix in the documented feature order.
%
% Output:
%   prediction   N x 1 ideal TDoA range difference [m].
%
% Checkpoint z-score normalization, model-specific input reshaping, network
% prediction, and output de-normalization are centralized here.

    validateattributes(model, {'struct'}, {'scalar'}, mfilename, 'model');
    required = {'network', 'inputFeatureCount', 'inputLayout', ...
        'normalization', 'outputUnits'};
    for i = 1:numel(required)
        if ~isfield(model, required{i})
            error('model:InvalidLoadedModel', ...
                'Loaded model is missing field "%s".', required{i});
        end
    end
    validateattributes(rawFeatures, {'numeric'}, {'2d', 'real'}, ...
        mfilename, 'rawFeatures');
    if size(rawFeatures, 2) ~= model.inputFeatureCount
        error('model:FeatureShapeMismatch', ...
            'Expected N-by-%d raw features, received %d-by-%d.', ...
            model.inputFeatureCount, size(rawFeatures, 1), size(rawFeatures, 2));
    end

    normalizedFeatures = (double(rawFeatures) - ...
        model.normalization.muX) ./ model.normalization.sigmaX;

    switch string(model.inputLayout)
        case "feature_rows"
            networkInput = normalizedFeatures;
        case "feature_image_110x1"
            networkInput = reshape(normalizedFeatures.', ...
                [model.inputFeatureCount, 1, 1, size(normalizedFeatures, 1)]);
        otherwise
            error('model:UnsupportedInputLayout', ...
                'Unsupported model input layout "%s".', model.inputLayout);
    end

    normalizedPrediction = predict(model.network, networkInput);
    normalizedPrediction = double(normalizedPrediction(:));
    if numel(normalizedPrediction) ~= size(rawFeatures, 1)
        error('model:UnexpectedPredictionShape', ...
            'Network returned %d values for %d feature rows.', ...
            numel(normalizedPrediction), size(rawFeatures, 1));
    end
    prediction = normalizedPrediction .* model.normalization.sigmaY + ...
        model.normalization.muY;
end

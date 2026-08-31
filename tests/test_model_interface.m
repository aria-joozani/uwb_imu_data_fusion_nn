function tests = test_model_interface
%TEST_MODEL_INTERFACE Regression tests for active FNN inference.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testCase.TestData.projectRoot = setup_project();
end

function testFnnPredictionMatchesInlineFormula(testCase)
    config = tdoa_model_config('fnn', testCase.TestData.projectRoot);
    checkpoint = load(config.model.checkpointFile, ...
        'net', 'muX', 'sigmaX', 'muY', 'sigmaY');
    rawFeatures = [checkpoint.muX; ...
        checkpoint.muX + 0.125 .* checkpoint.sigmaX];

    normalized = (rawFeatures - checkpoint.muX) ./ checkpoint.sigmaX;
    oldPrediction = predict(checkpoint.net, normalized);
    oldPrediction = double(oldPrediction(:)) .* checkpoint.sigmaY + checkpoint.muY;

    model = load_tdoa_correction_model(config);
    newPrediction = predict_tdoa_correction(model, rawFeatures);
    testCase.verifyEqual(newPrediction, oldPrediction, 'AbsTol', 1e-12);
end

function testFeatureWidthValidation(testCase)
    config = tdoa_model_config('fnn', testCase.TestData.projectRoot);
    model = load_tdoa_correction_model(config);
    testCase.verifyError(@() predict_tdoa_correction(model, zeros(1,109)), ...
        'model:FeatureShapeMismatch');
end

function testUnknownModelType(testCase)
    testCase.verifyError(@() tdoa_model_config('unknown-model'), ...
        'model:UnknownType');
end

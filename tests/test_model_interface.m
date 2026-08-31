function tests = test_model_interface
%TEST_MODEL_INTERFACE Regression tests for active FNN inference.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testCase.TestData.projectRoot = setup_project();
    config = tdoa_model_config('fnn', testCase.TestData.projectRoot);
    testCase.TestData.checkpoint = load(config.model.checkpointFile, ...
        'net', 'muX', 'sigmaX', 'muY', 'sigmaY');
    testCase.TestData.model = load_tdoa_correction_model(config);
end

function testFnnPredictionMatchesInlineFormula(testCase)
    checkpoint = testCase.TestData.checkpoint;
    rawFeatures = [checkpoint.muX; ...
        checkpoint.muX + 0.125 .* checkpoint.sigmaX];

    normalized = (rawFeatures - checkpoint.muX) ./ checkpoint.sigmaX;
    oldPrediction = predict(checkpoint.net, normalized);
    oldPrediction = double(oldPrediction(:)) .* checkpoint.sigmaY + checkpoint.muY;

    newPrediction = predict_tdoa_correction( ...
        testCase.TestData.model, rawFeatures);
    testCase.verifyEqual(newPrediction, oldPrediction, 'AbsTol', 1e-12);
end

function testFeatureWidthValidation(testCase)
    testCase.verifyError(@() predict_tdoa_correction( ...
        testCase.TestData.model, zeros(1,109)), ...
        'model:FeatureShapeMismatch');
end

function testNormalizationStatisticsComeFromCheckpoint(testCase)
    checkpoint = testCase.TestData.checkpoint;
    normalization = testCase.TestData.model.normalization;

    testCase.verifyEqual(normalization.muX, reshape(checkpoint.muX, 1, []));
    testCase.verifyEqual(normalization.sigmaX, ...
        reshape(checkpoint.sigmaX, 1, []));
    testCase.verifyEqual(normalization.muY, double(checkpoint.muY));
    testCase.verifyEqual(normalization.sigmaY, double(checkpoint.sigmaY));
end

function testUnknownModelType(testCase)
    testCase.verifyError(@() tdoa_model_config('unknown-model'), ...
        'model:UnknownType');
end

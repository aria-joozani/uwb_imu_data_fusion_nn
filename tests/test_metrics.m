function tests = test_metrics
%TEST_METRICS Known-value tests for centralized localization metrics.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    setup_project();
end

function testScalarTdoaMetrics(testCase)
    metrics = calculate_tdoa_metrics([1; 2; 3], [0; 2; 4]);

    testCase.verifyEqual(metrics.ERROR, [1; 0; -1]);
    testCase.verifyEqual(metrics.RMSE, sqrt(2/3), 'AbsTol', 1e-15);
    testCase.verifyEqual(metrics.MAE, 2/3, 'AbsTol', 1e-15);
    testCase.verifyEqual(metrics.MEDAE, 1);
    testCase.verifyEqual(metrics.MAX, 1);
    testCase.verifyEqual(metrics.BIAS, 0);
    testCase.verifyEqual(metrics.STD, 1);
    testCase.verifyEqual(metrics.COUNT, 3);
    testCase.verifyEqual(metrics.ERROR_CONVENTION, ...
        'reference_minus_estimate');
end

function testPositionMetrics(testCase)
    reference = zeros(2, 3);
    estimate = [3 4 0; 0 0 12];
    metrics = calculate_position_metrics(reference, estimate);

    testCase.verifyEqual(metrics.ERROR_XYZ, estimate);
    testCase.verifyEqual(metrics.ERROR_NORM, [5; 12]);
    testCase.verifyEqual(metrics.RMSE_X, sqrt(9/2), 'AbsTol', 1e-15);
    testCase.verifyEqual(metrics.RMSE_Y, sqrt(16/2), 'AbsTol', 1e-15);
    testCase.verifyEqual(metrics.RMSE_Z, sqrt(144/2), 'AbsTol', 1e-15);
    testCase.verifyEqual(metrics.RMSE_3D, sqrt(169/2), 'AbsTol', 1e-15);
    testCase.verifyEqual(metrics.RMS_ALL, metrics.RMSE_3D, 'AbsTol', 1e-15);
    testCase.verifyEqual(metrics.MAE_3D, 8.5);
    testCase.verifyEqual(metrics.LEGACY_MA_XXY, 5);
    testCase.verifyEqual(metrics.ERROR_CONVENTION, ...
        'estimate_minus_reference');
end

function testMetricSizeValidation(testCase)
    testCase.verifyError(@() calculate_tdoa_metrics([1; 2], 1), ...
        'metrics:SizeMismatch');
    testCase.verifyError(@() calculate_position_metrics( ...
        zeros(2, 3), zeros(3, 3)), 'metrics:SizeMismatch');
end

function tests = test_baseline_regression
%TEST_BASELINE_REGRESSION Protect compact historical baseline reconstruction.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    setup_project();
end

function testHistoricalHeadlineValues(testCase)
    config = load_experiment_config('baseline');
    config.evaluation.writeOutput = false;
    results = run_baseline_evaluation(config);

    testCase.verifyEqual(results.metadata.flightCount, 21);
    testCase.verifyEqual(height(results.perFlight), 336);
    testCase.verifyEqual(height(results.summary), 576);

    headline = results.summary( ...
        results.summary.Level == "overall" & ...
        results.summary.Group == "all" & ...
        results.summary.Task == "tdoa" & ...
        results.summary.Metric == "rmse_m", :);
    expected = [0.392157142857143; 0.293180952380952; ...
        0.282990476190476; 0.291595238095238];
    testCase.verifyEqual(headline.MeanOfFlightMetric, expected, ...
        'AbsTol', 1e-12);
end

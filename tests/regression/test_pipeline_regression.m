function tests = test_pipeline_regression
%TEST_PIPELINE_REGRESSION Frozen representative preprocessing regression.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    projectRoot = setup_project();
    fixtureRoot = fullfile(projectRoot, 'tests', 'regression', 'fixtures');
    config = legacy_pipeline_config(projectRoot);
    config.dataset.csvFile = fullfile(fixtureRoot, 'representative_flight.csv');
    config.dataset.anchorFile = fullfile(fixtureRoot, 'representative_anchors.txt');
    config.dataset.includeRawTable = false;
    config.preprocessing.downsampleFactor = 2;
    config.preprocessing.anchorPairs = [7 0; 0 1];

    dataset = load_experiment_dataset(config);
    synchronized = synchronize_sensor_data(dataset, config);
    testCase.TestData.processed = preprocess_sensor_data(synchronized, config);
    testCase.TestData.fixtureRoot = fixtureRoot;
end

function testFrozenImuOutput(testCase)
    expected = readmatrix(fullfile(testCase.TestData.fixtureRoot, ...
        'expected_processed_imu.csv'));
    processed = testCase.TestData.processed;
    actual = [processed.timestamps.imu, processed.imu.samples];

    testCase.verifySize(actual, size(expected));
    testCase.verifyEqual(actual, expected, 'AbsTol', 1e-12);
end

function testFrozenUwbAndGroundTruthOutput(testCase)
    expected = readmatrix(fullfile(testCase.TestData.fixtureRoot, ...
        'expected_processed_uwb.csv'));
    processed = testCase.TestData.processed;
    actual = [processed.uwb.tdoaAll, ...
        processed.groundTruth.atUwb(:, 2:4), ...
        processed.uwb.idealTdoa(:, 4)];

    testCase.verifySize(actual, size(expected));
    testCase.verifyEqual(actual, expected, 'AbsTol', 1e-12);
end

function testFrozenMetadataAndOrdering(testCase)
    processed = testCase.TestData.processed;
    testCase.verifyEqual(processed.metadata.commonTimeOrigin, 9);
    testCase.verifyEqual(processed.metadata.downsampleFactor, 2);
    testCase.verifyEqual(processed.metadata.anchorPairs, [7 0; 0 1]);
    testCase.verifyEqual(processed.metadata.sampleCounts, ...
        struct('imu', 6, 'uwb', 5, 'groundTruth', 11));
    testCase.verifyEqual(processed.uwb.tdoaAll(:, 1), ...
        sort(processed.uwb.tdoaAll(:, 1)));
end

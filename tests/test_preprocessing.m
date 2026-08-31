function tests = test_preprocessing
%TEST_PREPROCESSING Synthetic synchronization and preprocessing tests.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    setup_project();
end

function testLegacyStageContracts(testCase)
    dataset = syntheticDataset();
    config = legacy_pipeline_config();
    config.preprocessing.downsampleFactor = 2;
    config.preprocessing.anchorPairs = [7 0];

    synchronized = synchronize_sensor_data(dataset, config);
    processed = preprocess_sensor_data(synchronized, config);

    testCase.verifyEqual(synchronized.metadata.commonTimeOrigin, 9.5);
    testCase.verifyEqual(synchronized.timestamps.imu, (0.5:1:7.5).');
    testCase.verifyEqual(synchronized.imu.samples(:,1:3), ...
        dataset.imu.accelerometer(:,2:4));
    testCase.verifyEqual(synchronized.imu.samples(:,4:6), ...
        dataset.imu.gyroscope(:,2:4));
    testCase.verifyEqual(synchronized.uwb.tdoa(:,1), (1:4).');

    testCase.verifyEqual(processed.timestamps.imu, [0.5; 2.5; 4.5; 6.5]);
    testCase.verifyEqual(processed.timestamps.uwb, [1; 3]);
    testCase.verifyEqual(processed.uwb.tdoaAll(:,2:3), [7 0; 7 0]);
    testCase.verifyEqual(processed.groundTruth.atUwb(:,2), [1; 3], ...
        'AbsTol', 1e-12);
    testCase.verifyEqual(processed.uwb.idealTdoa(:,4), [1; 1], ...
        'AbsTol', 1e-12);
end

function testUnsupportedSynchronizationFails(testCase)
    dataset = syntheticDataset();
    config = legacy_pipeline_config();
    config.preprocessing.gyroscopeInterpolationMethod = 'spline';
    testCase.verifyError(@() synchronize_sensor_data(dataset, config), ...
        'preprocessing:UnsupportedSynchronizationMode');
end

function dataset = syntheticDataset()
    imuTime = (10:17).';
    accelerometer = [imuTime, (1:8).', (11:18).', (21:28).'];
    gyroscope = [imuTime, (31:38).', (41:48).', (51:58).'];
    tdoaTime = (10.5:1:13.5).';
    tdoa = [tdoaTime, repmat([7 0], 4, 1), (0.1:0.1:0.4).'];
    groundTruthTime = [9.5; (10:18).'];
    position = [groundTruthTime - 9.5, ...
        zeros(numel(groundTruthTime), 2)];
    pose = [groundTruthTime, position, ...
        zeros(numel(groundTruthTime), 3), ones(numel(groundTruthTime), 1)];

    anchorPositions = zeros(8, 3);
    anchorPositions(8, :) = [1 0 0];
    dataset = struct();
    dataset.imu = struct( ...
        'accelerometer', accelerometer, ...
        'gyroscope', gyroscope);
    dataset.uwb = struct('tdoa', tdoa);
    dataset.groundTruth = struct('pose', pose);
    dataset.anchors = struct( ...
        'positions', anchorPositions, ...
        'quaternions', repmat([0 0 0 1], 8, 1), ...
        'names', "an" + string((0:7).'), ...
        'positionUnits', 'm', ...
        'quaternionOrder', 'qx_qy_qz_qw', ...
        'coordinateFrame', 'synthetic');
    dataset.metadata = struct('flightName', 'synthetic', ...
        'units', struct('time', 's'));
end

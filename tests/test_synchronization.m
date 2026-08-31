function tests = test_synchronization
%TEST_SYNCHRONIZATION Verify timestamp and gyroscope alignment contracts.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    setup_project();
end

function testLinearGyroscopeInterpolationAndTimeOrigin(testCase)
    dataset = synchronizationDataset([1; 2; 3], [0; 2; 4]);
    synchronized = synchronize_sensor_data(dataset, legacy_pipeline_config());

    expectedGyroscope = [10 20 -10; 20 40 -20; 30 60 -30];
    testCase.verifyEqual(synchronized.imu.samples(:, 4:6), ...
        expectedGyroscope, 'AbsTol', 1e-12);
    testCase.verifyEqual(synchronized.metadata.commonTimeOrigin, 0.5);
    testCase.verifyEqual(synchronized.timestamps.imu, [0.5; 1.5; 2.5]);
    testCase.verifyEqual(synchronized.uwb.tdoa(:, 1), 1);
    testCase.verifyEqual(synchronized.timestamps.groundTruth, [1; 2; 3]);
end

function testLinearGyroscopeExtrapolation(testCase)
    dataset = synchronizationDataset([-1; 5], [0; 4]);
    synchronized = synchronize_sensor_data(dataset, legacy_pipeline_config());

    expectedGyroscope = [-10 -20 10; 50 100 -50];
    testCase.verifyEqual(synchronized.imu.samples(:, 4:6), ...
        expectedGyroscope, 'AbsTol', 1e-12);
end

function dataset = synchronizationDataset(accelerometerTime, gyroscopeTime)
    accelerometer = [accelerometerTime, zeros(numel(accelerometerTime), 3)];
    gyroscope = [gyroscopeTime, 10 .* gyroscopeTime, ...
        20 .* gyroscopeTime, -10 .* gyroscopeTime];
    groundTruthTime = [0.5; 1.5; 2.5; 3.5];
    groundTruthPose = [groundTruthTime, zeros(4, 3), zeros(4, 3), ones(4, 1)];

    dataset = struct();
    dataset.imu = struct( ...
        'accelerometer', accelerometer, 'gyroscope', gyroscope);
    dataset.uwb = struct('tdoa', [1.5 7 0 0.1]);
    dataset.groundTruth = struct('pose', groundTruthPose);
    dataset.anchors = struct('positions', zeros(8, 3));
    dataset.metadata = struct('flightName', 'synthetic-synchronization');
end

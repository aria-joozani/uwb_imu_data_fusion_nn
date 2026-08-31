function tests = test_dataset_loader
%TEST_DATASET_LOADER Synthetic file tests for load_experiment_dataset.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    setup_project();
    import matlab.unittest.fixtures.TemporaryFolderFixture
    fixture = testCase.applyFixture(TemporaryFolderFixture);
    testCase.TestData.folder = fixture.Folder;
    testCase.TestData.csvFile = fullfile(fixture.Folder, 'flight.csv');
    testCase.TestData.anchorFile = fullfile(fixture.Folder, 'anchors.txt');

    writeSyntheticFlight(testCase.TestData.csvFile);
    writeSyntheticAnchors(testCase.TestData.anchorFile);
end

function testLoadsExpectedStructure(testCase)
    config.dataset = struct( ...
        'csvFile', testCase.TestData.csvFile, ...
        'anchorFile', testCase.TestData.anchorFile, ...
        'includeRawTable', true);
    dataset = load_experiment_dataset(config);

    testCase.verifyEqual(height(dataset.rawTable), 3);
    testCase.verifySize(dataset.uwb.tdoa, [3 4]);
    testCase.verifySize(dataset.imu.accelerometer, [3 4]);
    testCase.verifySize(dataset.imu.gyroscope, [3 4]);
    testCase.verifySize(dataset.groundTruth.pose, [3 8]);
    testCase.verifySize(dataset.anchors.positions, [8 3]);
    testCase.verifySize(dataset.anchors.quaternions, [8 4]);
    testCase.verifyEqual(dataset.anchors.names, "an" + string((0:7).'));
    testCase.verifyEqual(dataset.metadata.rawRowCount, 3);
    testCase.verifyEqual(dataset.metadata.units.tdoaRangeDifference, 'm');
end

function testCanReleaseRawTable(testCase)
    config.dataset = struct( ...
        'csvFile', testCase.TestData.csvFile, ...
        'anchorFile', testCase.TestData.anchorFile, ...
        'includeRawTable', false);
    dataset = load_experiment_dataset(config);

    testCase.verifyTrue(istable(dataset.rawTable));
    testCase.verifyEmpty(dataset.rawTable);
    testCase.verifySize(dataset.uwb.tdoa, [3 4]);
end

function testMissingFlightFailsClearly(testCase)
    config.dataset = struct( ...
        'csvFile', fullfile(testCase.TestData.folder, 'missing.csv'), ...
        'anchorFile', testCase.TestData.anchorFile);
    testCase.verifyError(@() load_experiment_dataset(config), ...
        'dataset:MissingFlightFile');
end

function writeSyntheticFlight(csvFile)
    n = 3;
    t_tdoa = (1:n).'; idA = [7; 0; 1]; idB = [0; 1; 2];
    tdoa_meas = [0.1; 0.2; 0.3];
    t_acc = (1:n).'; acc_x = [1; 2; 3]; acc_y = acc_x + 1; acc_z = acc_x + 2;
    t_gyro = (1:n).'; gyro_x = [4; 5; 6]; gyro_y = gyro_x + 1; gyro_z = gyro_x + 2;
    t_pose = (1:n).'; pose_x = [0; 1; 2]; pose_y = pose_x + 1; pose_z = pose_x + 2;
    pose_qx = zeros(n,1); pose_qy = zeros(n,1); pose_qz = zeros(n,1); pose_qw = ones(n,1);
    flight = table(t_tdoa, idA, idB, tdoa_meas, ...
        t_acc, acc_x, acc_y, acc_z, ...
        t_gyro, gyro_x, gyro_y, gyro_z, ...
        t_pose, pose_x, pose_y, pose_z, ...
        pose_qx, pose_qy, pose_qz, pose_qw);
    writetable(flight, csvFile);
end

function writeSyntheticAnchors(anchorFile)
    fileId = fopen(anchorFile, 'w');
    assert(fileId >= 0, 'Unable to create synthetic anchor file.');
    cleaner = onCleanup(@() fclose(fileId));
    for anchorId = 0:7
        fprintf(fileId, 'an%d_p,%g,%g,%g\n', ...
            anchorId, anchorId, 0, 0);
    end
    for anchorId = 0:7
        fprintf(fileId, 'an%d_quat,0,0,0,1\n', anchorId);
    end
end

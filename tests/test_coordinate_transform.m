function tests = test_coordinate_transform
%TEST_COORDINATE_TRANSFORM Verify active ESKF rotation assumptions.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    setup_project();
end

function testScalarFirstQuaternionMapsBodyToWorld(testCase)
    halfAngle = pi / 4;
    qWorldBody = [cos(halfAngle), 0, 0, sin(halfAngle)];
    filter = ESKF(zeros(6, 1), qWorldBody, eye(9), 2);

    bodyXAxisInWorld = filter.R * [1; 0; 0];
    testCase.verifyEqual(bodyXAxisInWorld, [0; 1; 0], 'AbsTol', 1e-12);
end

function testIdentityAttitudeCancelsStationarySpecificForce(testCase)
    filter = ESKF(zeros(6, 1), [1 0 0 0], eye(9), 2);
    stationaryImu = [0 0 1 0 0 0];

    filter.predict(stationaryImu, 0.1, true, 2);

    testCase.verifyEqual(filter.Xpo(2, :), zeros(1, 6), 'AbsTol', 1e-12);
    testCase.verifyEqual(filter.q_list(2, :), [1 0 0 0], 'AbsTol', 1e-12);
end

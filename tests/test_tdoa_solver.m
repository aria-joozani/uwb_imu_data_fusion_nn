function tests = test_tdoa_solver
%TEST_TDOA_SOLVER Synthetic checks for TDoA generation and NLS solving.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    setup_project();
    testCase.TestData.anchors = [ ...
        0 0 0; 4 0 0; 0 5 0; 0 0 3; ...
        4 5 0; 4 0 3; 0 5 3; 4 5 3];
    testCase.TestData.position = [1.2 1.7 1.1];
    testCase.TestData.pairIds = (0:7).';
    testCase.TestData.generated = generatedRingMeasurements( ...
        testCase.TestData.position, testCase.TestData.pairIds, ...
        testCase.TestData.anchors);
end

function testKnownNlsSignMismatchIsExplicit(testCase)
    p = testCase.TestData.position;
    pairIds = testCase.TestData.pairIds;
    generated = testCase.TestData.generated;
    anchors = testCase.TestData.anchors;

    generatedConventionResidual = tdoa_residuals_3d( ...
        p, pairIds, generated, anchors);
    solverConventionResidual = tdoa_residuals_3d( ...
        p, pairIds, -generated, anchors);

    testCase.verifyGreaterThan(norm(generatedConventionResidual), 1);
    testCase.verifyEqual(solverConventionResidual, zeros(8, 1), ...
        'AbsTol', 1e-12);
    testCase.verifyEqual(generatedConventionResidual, -2 .* generated, ...
        'AbsTol', 1e-12);
end

function testThreeDimensionalSolverRecoversKnownPosition(testCase)
    estimate = solve_tdoa_nls_3d([1 1 1], ...
        testCase.TestData.pairIds, -testCase.TestData.generated, ...
        testCase.TestData.anchors, 500);

    testCase.verifyEqual(estimate, testCase.TestData.position, ...
        'AbsTol', 1e-6);
end

function testTwoDimensionalSolverRecoversKnownPositionAtFixedHeight(testCase)
    position = testCase.TestData.position;
    estimate = solve_tdoa_nls_2d([1 1], position(3), ...
        testCase.TestData.pairIds, -testCase.TestData.generated, ...
        testCase.TestData.anchors, 500);

    testCase.verifyEqual(estimate, position(1:2), 'AbsTol', 1e-6);
end

function measurements = generatedRingMeasurements(position, pairIds, anchors)
    measurements = zeros(numel(pairIds), 1);
    for i = 1:numel(pairIds)
        anchorA = pairIds(i);
        anchorB = mod(anchorA + 1, 8);
        measurements(i) = generate_tdoa_from_gt(position, ...
            anchors(anchorA + 1, :), anchors(anchorB + 1, :));
    end
end

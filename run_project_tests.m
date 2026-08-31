function results = run_project_tests()
%RUN_PROJECT_TESTS Run the repository MATLAB unit and regression tests.
%
% results = run_project_tests()

    projectRoot = setup_project();
    import matlab.unittest.TestSuite

    suite = TestSuite.fromFolder(fullfile(projectRoot, 'tests'), ...
        'IncludingSubfolders', true);
    results = run(suite);
    disp(table(results));

    if any([results.Failed]) || any([results.Incomplete])
        error('tests:Failure', ...
            '%d of %d project tests failed or were incomplete.', ...
            sum([results.Failed] | [results.Incomplete]), numel(results));
    end
end

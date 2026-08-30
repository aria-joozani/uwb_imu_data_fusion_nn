function projectRoot = setup_project()
%SETUP_PROJECT Add categorized project code folders to the MATLAB path.
%
% Run this once from the repository root before invoking a script:
%   setup_project;
%   run_baseline_evaluation;

    projectRoot = fileparts(mfilename('fullpath'));
    addpath(projectRoot);
    addpath(fullfile(projectRoot, 'config'));

    sourceStages = {'data', 'preprocessing', 'uwb', 'localization', ...
        'eskf', 'models', 'evaluation', 'visualization', 'utilities'};
    for i = 1:numel(sourceStages)
        addpath(fullfile(projectRoot, 'src', sourceStages{i}));
    end

    scriptCategories = {'preprocessing', 'training', 'evaluation', ...
        'deployment', 'visualization'};
    for i = 1:numel(scriptCategories)
        addpath(fullfile(projectRoot, 'scripts', scriptCategories{i}));
    end
end

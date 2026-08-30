function plot_anchors_3d(anchor_file)
% plot_anchors_3d   Visualize UWB anchor positions in 3D
%
% Usage:
%   plot_anchors_3d('anchor_const1_survey.txt')

    projectRoot = setup_project();
    if nargin < 1
        anchor_file = fullfile(projectRoot, 'survey-results', ...
            'anchor_const1_survey.txt');
    end

    % Read the survey file (comma-separated text file)
    T = readtable(anchor_file, ...
                  'FileType','text', ...
                  'Delimiter',',', ...
                  'ReadVariableNames',false);

    % Identify rows that contain anchor positions (rows with "_p")
    isPos = contains(T.Var1, '_p');

    % Extract anchor names (e.g., "an0" from "an0_p")
    anchorNames = T.Var1(isPos);
    for i = 1:numel(anchorNames)
        anchorNames{i} = anchorNames{i}(1:3); % keep only "an0", "an1", ...
    end

    % Extract anchor XYZ coordinates
    anchorPos = [T{isPos,2}, T{isPos,3}, T{isPos,4}];  % Nx3 matrix

    x = anchorPos(:,1);
    y = anchorPos(:,2);
    z = anchorPos(:,3);

    % Plot the 3D anchor constellation
    figure('Name','UWB Anchor Constellation');
    scatter3(x, y, z, 80, 'filled');
    hold on;
    grid on; box on;
    axis equal;

    % Add text labels to each anchor
    for i = 1:length(x)
        text(x(i), y(i), z(i), ['  ' anchorNames{i}], ...
            'FontSize', 10, 'Interpreter','none');
    end

    % Axis labels and title
    xlabel('X [m]');
    ylabel('Y [m]');
    zlabel('Z [m]');
    title(sprintf('Anchor Constellation from "%s"', anchor_file), ...
          'Interpreter','none');

    % Adjust view angle for better visualization
    view(10, 10);
end

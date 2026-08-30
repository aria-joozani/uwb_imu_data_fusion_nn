%% Plot TDOA performance vs clutter level (Trials 1..6) per Trajectory (1..3)
% - Trials 1..4: static objects increase (more clutter)
% - Trials 5..6: dynamic objects
%
% Expected table format (either in RMS and/or MAE excel):
%  Column 1: test name like "تست1-مسیر1" or "test1-traj1"
%  Next columns: Raw, FNN, CNN1, CNN2 (order can be configured below)

clc; close all; clear;
projectRoot = setup_project();

%% ---- User config ----
rmsFile = fullfile(projectRoot, 'artifacts', 'baseline', 'source', ...
    'result_overall_tdoa_rms.xlsx');
maeFile = fullfile(projectRoot, 'artifacts', 'baseline', 'source', ...
    'result_overall_tdoa_ma.xlsx');

% Methods display names (must match columns mapping below)
methodNames = ["Raw","FNN","CNN1","CNN2"];

% Column mapping: which columns in the Excel correspond to which method?
% If your excel has headers, the script will try to auto-detect by header names.
% If not, it will fallback to col indices [2 3 4 5].
fallbackMethodCols = [2 3 4 5];

% Trials and trajectories to plot
trials = 1:6;
trajList = 1:3;

% Style
yLabelRMS = 'RMS error (m)';
yLabelMAE = 'MAE error (m)';

%% ---- Load and plot ----
if ~isempty(rmsFile)
    Trms = readtable(rmsFile, 'VariableNamingRule','preserve');
    D_rms = table_to_cube(Trms, trials, trajList, methodNames, fallbackMethodCols);
    plot_per_trajectory(D_rms, trials, trajList, methodNames, yLabelRMS, "RMS");
end

if ~isempty(maeFile)
    Tmae = readtable(maeFile, 'VariableNamingRule','preserve');
    D_mae = table_to_cube(Tmae, trials, trajList, methodNames, fallbackMethodCols);
    plot_per_trajectory(D_mae, trials, trajList, methodNames, yLabelMAE, "MAE");
end

%% ---- Optional: Print summary stats (mean over trials 1..4 vs 5..6) ----
if exist('D_rms','var')
    print_static_dynamic_summary(D_rms, methodNames, "RMS");
end
if exist('D_mae','var')
    print_static_dynamic_summary(D_mae, methodNames, "MAE");
end


%% ===================== Helper functions =====================

function D = table_to_cube(T, trials, trajList, methodNames, fallbackMethodCols)
% Returns D(trial, traj, method) as double with NaNs where missing.

    % Identify the "name" column (first column)
    nameCol = 1;
    testNames = T{:, nameCol};

    % Determine method columns
    methodCols = detect_method_cols(T, methodNames, fallbackMethodCols);

    % Preallocate cube
    D = nan(max(trials), max(trajList), numel(methodNames));

    for i = 1:height(T)
        nm = string(testNames(i));
        [trialId, trajId] = parse_trial_traj(nm);

        if ismember(trialId, trials) && ismember(trajId, trajList)
            for m = 1:numel(methodNames)
                val = T{i, methodCols(m)};
                if iscell(val), val = val{1}; end
                D(trialId, trajId, m) = double(val);
            end
        end
    end
end

function cols = detect_method_cols(T, methodNames, fallbackCols)
% Try to match headers; fallback to fixed indices.

    vars = string(T.Properties.VariableNames);

    % Common header patterns (Persian/English)
    patterns = {
        ["raw","خام","data_raw","داده خام"], ...
        ["fnn","پیش خور","پيش خور","feedforward"], ...
        ["cnn1","کانولوشنی 1","کانولوشنی۱","conv1"], ...
        ["cnn2","کانولوشنی 2","کانولوشنی۲","conv2"]
    };

    cols = nan(1, numel(methodNames));
    for m = 1:numel(methodNames)
        pat = patterns{m};
        hit = false;
        for p = 1:numel(pat)
            idx = find(contains(lower(vars), lower(pat(p))), 1, 'first');
            if ~isempty(idx)
                cols(m) = idx;
                hit = true;
                break;
            end
        end
        if ~hit
            cols(m) = fallbackCols(m);
        end
    end
end

function [trialId, trajId] = parse_trial_traj(nameStr)
% Parses strings like:
% "تست3-مسیر2" , "test3-traj2", "trial3-traj2", "تست7-کنترل دستی1" (will map to traj if possible)
%
% Output:
%   trialId: numeric
%   trajId : numeric (1..3) if found, else NaN

    s = lower(string(nameStr));
    s = replace(s, " ", "");
    s = replace(s, "ـ", "-");

    % Trial/test number
    % Matches: تست1, test1, trial1
    tokT = regexp(s, '(تست|test|trial)(\d+)', 'tokens', 'once');
    if isempty(tokT)
        trialId = NaN;
    else
        trialId = str2double(tokT{2});
    end

    % Trajectory number
    % Matches: مسیر2, traj2, trajectory2
    tokR = regexp(s, '(مسیر|traj|trajectory)(\d+)', 'tokens', 'once');
    if isempty(tokR)
        % Some datasets have "manual control1/2/3" -> treat as traj1/2/3 if present
        tokM = regexp(s, '(کنترل?دستی|manualcontrol|manual)(\d+)', 'tokens', 'once');
        if isempty(tokM)
            trajId = NaN;
        else
            trajId = str2double(tokM{2});
        end
    else
        trajId = str2double(tokR{2});
    end
end

function plot_per_trajectory(D, trials, trajList, methodNames, yLab, metricTag)
% One figure per trajectory with all methods across trials.

    for tr = trajList
        figure('Name', sprintf('%s - Trajectory %d', metricTag, tr), 'Color', 'w');
        hold on; grid on;

        x = trials;

        for m = 1:numel(methodNames)
            y = squeeze(D(x, tr, m));
            plot(x, y, '-o', 'LineWidth', 1.6, 'MarkerSize', 6, 'DisplayName', methodNames(m));
        end

        % Separator between static clutter (1..4) and dynamic (5..6)
        xline(4.5, '--', 'Static \rightarrow Dynamic', 'LabelVerticalAlignment','bottom');

        xlabel('Trial');
        ylabel(yLab);
        title(sprintf('%s vs Trial (Trajectory %d)', metricTag, tr));
        legend('Location','best');

        % Optional: emphasize static region
        % (No custom colors; uses default)
        yl = ylim;
        patch([1 4 4 1], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
              'FaceAlpha', 0.10, 'EdgeColor', 'none', 'DisplayName','');
        uistack(findobj(gca,'Type','line'),'top');

        % Save
        outName = sprintf('TDOA_%s_Traj%d.png', metricTag, tr);
        exportgraphics(gcf, outName, 'Resolution', 200);
    end
end

function print_static_dynamic_summary(D, methodNames, metricTag)
% Print mean over trials 1..4 vs trials 5..6, averaged over trajectories (1..3)

    staticTrials  = 1:4;
    dynamicTrials = 5:6;

    fprintf('\n============================================\n');
    fprintf('Summary (%s): mean over Traj(1..3)\n', metricTag);
    fprintf('--------------------------------------------\n');
    fprintf('%-10s | %-12s | %-12s | %-10s\n', 'Method', 'Static(1..4)', 'Dynamic(5..6)', 'Delta');
    fprintf('--------------------------------------------\n');

    for m = 1:numel(methodNames)
        S = D(staticTrials, 1:3, m);
        Y = D(dynamicTrials, 1:3, m);

        muS = mean(S(:), 'omitnan');
        muY = mean(Y(:), 'omitnan');
        dlt = muY - muS;

        fprintf('%-10s | %-12.4f | %-12.4f | %-10.4f\n', methodNames(m), muS, muY, dlt);
    end
    fprintf('============================================\n');
end

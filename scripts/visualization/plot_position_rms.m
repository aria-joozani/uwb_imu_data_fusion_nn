clc; close all; clear all;
projectRoot = setup_project();

%% Load excel
fileName = fullfile(projectRoot, 'artifacts', 'baseline', 'source', ...
    'result_position_rms.xlsx');
T = readtable(fileName);

% Ensure Trial is string
trialStr = string(T.Trial);

%% Parse Trial field
% Supports:
%   trial<k>-traj<j>     e.g. trial4-traj1
%   trial<k>-manual<m>   e.g. trial7-manual2

N = height(T);
trialNum = nan(N,1);
trajNum  = nan(N,1);
isTraj   = false(N,1);
isManual = false(N,1);

for i = 1:N
    s = trialStr(i);

    tok = regexp(s, "^trial(\d+)-traj(\d+)$", "tokens", "once");
    if ~isempty(tok)
        trialNum(i) = str2double(tok{1});
        trajNum(i)  = str2double(tok{2});
        isTraj(i)   = true;
        continue;
    end

    tok = regexp(s, "^trial(\d+)-manual(\d+)$", "tokens", "once");
    if ~isempty(tok)
        trialNum(i) = str2double(tok{1});
        trajNum(i)  = str2double(tok{2});  % manual index
        isManual(i) = true;
        continue;
    end
end

%% Select Trajectory 1 only (trial?-traj1)
traj_id = 3;
idx = isTraj & (trajNum == traj_id);

Tsel = T(idx,:);
tr   = trialNum(idx);

raw  = Tsel.raw;
fnn  = Tsel.fnn;
cnn1 = Tsel.cnn1;
cnn2 = Tsel.cnn2;

% Sort by trial number
[tr, ord] = sort(tr);
raw  = raw(ord);
fnn  = fnn(ord);
cnn1 = cnn1(ord);
cnn2 = cnn2(ord);

%% Plot
splitX = 4.5;  % Static (1..4) -> Dynamic (5..6) based on your scenario

figure('Color','w'); hold on; grid on;

% (Optional) dummy dashed legend item like your sample
h_dummy = plot(nan, nan, '--', 'LineWidth', 2);

h_raw  = plot(tr, raw , '-o', 'LineWidth', 2.5, 'MarkerSize', 9);
h_fnn  = plot(tr, fnn , '-o', 'LineWidth', 2.5, 'MarkerSize', 9);
h_cnn1 = plot(tr, cnn1, '-o', 'LineWidth', 2.5, 'MarkerSize', 9);
h_cnn2 = plot(tr, cnn2, '-o', 'LineWidth', 2.5, 'MarkerSize', 9);

xline(splitX, '--', 'LineWidth', 2);

title(sprintf('RMS vs Trial (Trajectory %d)', traj_id), 'FontWeight','bold');
xlabel('Trial');
ylabel('RMS error (m)');

xlim([min(tr) max(tr)]);
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

% Vertical text annotation (Static -> Dynamic)
yl = ylim;
text(splitX+0.05, yl(1) + 0.05*(yl(2)-yl(1)), 'Static  \rightarrow  Dynamic', ...
    'Rotation', 90, 'FontSize', 12, 'FontWeight','bold', ...
    'HorizontalAlignment', 'left');

legend([h_dummy, h_raw, h_fnn, h_cnn1, h_cnn2], ...
       {'data1','Raw','FNN','CNN1','CNN2'}, ...
       'Location','northeast');

% Optional save
% exportgraphics(gcf, sprintf('pos_rms_traj%d.png', traj_id), 'Resolution', 200);

%% prepare_data_for_ptq.m
% Load CSV datasets, build calibration + test tensors for PTQ, save to .mat
% Output file: prepared_data_for_ptq.mat
%
% Produces:
%   XCal4D  : [110 1 1 Ncal]   (normalized inputs)
%   XTest4D : [110 1 1 Ntest]  (normalized inputs)
%   YTest   : [Ntest 1]        (normalized target)
%
% Assumes you already have:
%   trained_tdoa_net_cnn_2.mat containing muX, sigmaX, muY, sigmaY

clc; clear; close all;

%% === 0) Load normalization stats from trained net ===
trainedFile = 'trained_tdoa_net_cnn_2.mat';
S = load(trainedFile, 'muX', 'sigmaX', 'muY', 'sigmaY');

muX    = S.muX;
sigmaX = S.sigmaX;
muY    = S.muY;
sigmaY = S.sigmaY;

% Safety
sigmaX(sigmaX == 0) = 1;
if sigmaY == 0
    sigmaY = 1;
end

fprintf('Loaded normalization stats from: %s\n', trainedFile);

%% === 1) CSV file list (same pattern as your training code) ===
csvFiles = {
    'export-data-set-r\const1-trial1-tdoa2_NN.csv';
    'export-data-set-r\const1-trial2-tdoa2_NN.csv';
    'export-data-set-r\const1-trial3-tdoa2_NN.csv';
    'export-data-set-r\const1-trial4-tdoa2_NN.csv';
    'export-data-set-r\const1-trial5-tdoa2_NN.csv';
    'export-data-set-r\const1-trial6-tdoa2_NN.csv';
    'export-data-set-r\const2-trial1-tdoa2_NN.csv';
    'export-data-set-r\const2-trial2-tdoa2_NN.csv';
    'export-data-set-r\const2-trial3-tdoa2_NN.csv';
    'export-data-set-r\const2-trial4-tdoa2_NN.csv';
    'export-data-set-r\const2-trial5-tdoa2_NN.csv';
    'export-data-set-r\const2-trial6-tdoa2_NN.csv';
    'export-data-set-r\const3-trial1-tdoa2_NN.csv';
    'export-data-set-r\const3-trial2-tdoa2_NN.csv';
    'export-data-set-r\const3-trial3-tdoa2_NN.csv';
    'export-data-set-r\const3-trial4-tdoa2_NN.csv';
    'export-data-set-r\const3-trial5-tdoa2_NN.csv';
    'export-data-set-r\const3-trial6-tdoa2_NN.csv';
    'export-data-set-r\const3-trial7-tdoa2-manual1_NN.csv';
    'export-data-set-r\const3-trial7-tdoa2-manual2_NN.csv';
    'export-data-set-r\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial1-tdoa2-traj2_NN.csv';
    'export-data-set-r\const4-trial1-tdoa2-traj3_NN.csv';
    'export-data-set-r\const4-trial2-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial2-tdoa2-traj2_NN.csv';
    'export-data-set-r\const4-trial2-tdoa2-traj3_NN.csv';
    'export-data-set-r\const4-trial3-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial3-tdoa2-traj2_NN.csv';
    'export-data-set-r\const4-trial3-tdoa2-traj3_NN.csv';
    'export-data-set-r\const4-trial4-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial4-tdoa2-traj2_NN.csv';
    'export-data-set-r\const4-trial4-tdoa2-traj3_NN.csv';
    'export-data-set-r\const4-trial6-tdoa2-traj1_NN.csv';
    'export-data-set-r\const4-trial6-tdoa2-traj2_NN.csv';
    'export-data-set-r\const4-trial6-tdoa2-traj3_NN.csv';
    'export-data-set-r\const4-trial7-tdoa2-manual1_NN.csv';
    'export-data-set-r\const4-trial7-tdoa2-manual2_NN.csv';
    'export-data-set-r\const4-trial7-tdoa2-manual3_NN.csv';
};

numFiles  = length(csvFiles);
rowCounts = zeros(numFiles, 1);

fig1 = uifigure('Name','import dataset...','Position',[500 400 420 130]);
d1 = uiprogressdlg(fig1, ...
    'Title','import dataset', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

%% === 2) First pass: row counts ===
for i = 1:numFiles
    if d1.CancelRequested
        close(fig1); error('Canceled by user.');
    end

    % update progress ~ every 1%
    if mod(i, max(1, round(numFiles*2/100))) == 0
        d1.Value = i/(numFiles*2);
        d1.Message = sprintf('Counting rows: %d / %d', i, numFiles);
        drawnow limitrate;
    end

    Tinfo = readtable(csvFiles{i});
    rowCounts(i) = height(Tinfo);
end

totalRows = sum(rowCounts);

%% === 3) Preallocate table and fill (second pass) ===
firstTable = readtable(csvFiles{1});
varNames = firstTable.Properties.VariableNames;
varTypes = varfun(@class, firstTable, 'OutputFormat', 'cell');

data_set = table('Size', [totalRows, numel(varNames)], ...
                 'VariableTypes', varTypes, ...
                 'VariableNames', varNames);

rowStart = 1;

for i = 1:numFiles
    if d1.CancelRequested
        close(fig1); error('Canceled by user.');
    end

    if mod(i, max(1, round(numFiles*2/100))) == 0
        d1.Value = (i+numFiles)/(numFiles*2);
        d1.Message = sprintf('Loading CSV: %d / %d', i, numFiles);
        drawnow limitrate;
    end

    Ti = readtable(csvFiles{i});
    rowEnd = rowStart + height(Ti) - 1;
    data_set(rowStart:rowEnd, :) = Ti;
    rowStart = rowEnd + 1;
end

d1.Value = 1;
d1.Message = 'Done.';
pause(0.2);
close(fig1);

%% === 4) Define inputs/outputs (same as training) ===
inputNames = { ...
    'acc_x_1', 'acc_y_1', 'acc_z_1', 'gyro_x_1', 'gyro_y_1', 'gyro_z_1', ...
    'acc_x_2', 'acc_y_2', 'acc_z_2', 'gyro_x_2', 'gyro_y_2', 'gyro_z_2', ...
    'acc_x_3', 'acc_y_3', 'acc_z_3', 'gyro_x_3', 'gyro_y_3', 'gyro_z_3', ...
    'acc_x_4', 'acc_y_4', 'acc_z_4', 'gyro_x_4', 'gyro_y_4', 'gyro_z_4', ...
    'acc_x_5', 'acc_y_5', 'acc_z_5', 'gyro_x_5', 'gyro_y_5', 'gyro_z_5', ...
    'acc_x_6', 'acc_y_6', 'acc_z_6', 'gyro_x_6', 'gyro_y_6', 'gyro_z_6', ...
    'acc_x_7', 'acc_y_7', 'acc_z_7', 'gyro_x_7', 'gyro_y_7', 'gyro_z_7', ...
    'acc_x_8', 'acc_y_8', 'acc_z_8', 'gyro_x_8', 'gyro_y_8', 'gyro_z_8', ...
    'acc_x_9', 'acc_y_9', 'acc_z_9', 'gyro_x_9', 'gyro_y_9', 'gyro_z_9', ...
    'acc_x_10', 'acc_y_10', 'acc_z_10', 'gyro_x_10', 'gyro_y_10', 'gyro_z_10', ...
    'acc_x_11', 'acc_y_11', 'acc_z_11', 'gyro_x_11', 'gyro_y_11', 'gyro_z_11', ...
    'acc_x_12', 'acc_y_12', 'acc_z_12', 'gyro_x_12', 'gyro_y_12', 'gyro_z_12', ...
    'acc_x_13', 'acc_y_13', 'acc_z_13', 'gyro_x_13', 'gyro_y_13', 'gyro_z_13', ...
    'acc_x_14', 'acc_y_14', 'acc_z_14', 'gyro_x_14', 'gyro_y_14', 'gyro_z_14', ...
    'acc_x_15', 'acc_y_15', 'acc_z_15', 'gyro_x_15', 'gyro_y_15', 'gyro_z_15', ...
    'acc_x_16', 'acc_y_16', 'acc_z_16', 'gyro_x_16', 'gyro_y_16', 'gyro_z_16', ...
    'acc_x_17', 'acc_y_17', 'acc_z_17', 'gyro_x_17', 'gyro_y_17', 'gyro_z_17', ...
    'anch_a_x', 'anch_a_y', 'anch_a_z', 'anch_b_x', 'anch_b_y', 'anch_b_z', ...
    'uwb_tdoA_last_gt', 'uwb_tdoA_now'};

outputName = 'uwb_tdoA_now_gt';

%% === 5) Build X/Y arrays and remove NaNs ===
X = table2array(data_set(:, inputNames));
Y = table2array(data_set(:, outputName));

validMask = all(~isnan(X), 2) & ~isnan(Y);
X = X(validMask, :);
Y = Y(validMask);

fprintf('Total samples after NaN removal: %d\n', size(X,1));

%% === 6) Normalize using TRAINED stats (same as training net) ===
% Your training used zscore(X) and saved muX/sigmaX. Reuse them here.
Xn = (X - muX) ./ sigmaX;
Yn = (Y - muY) ./ sigmaY;

%% === 7) Split into Calibration + Test sets ===
N = size(Xn, 1);
idx = randperm(N);

% You can tune these:
calRatio  = 0.10;   % 10% for calibration
testRatio = 0.15;   % 15% for final evaluation

Ncal  = max(200, floor(calRatio  * N));          % minimum 200
Ntest = max(1000, floor(testRatio * N));         % minimum 1000 (if you have enough)

% Clamp in case dataset is small
Ncal  = min(Ncal,  N);
Ntest = min(Ntest, N - Ncal);

calIdx  = idx(1:Ncal);
testIdx = idx(Ncal+1 : Ncal+Ntest);

XCal  = Xn(calIdx, :);
XTest = Xn(testIdx, :);
YTest = Yn(testIdx, :);

%% === 8) Reshape to 4D tensors (same as training) ===
% X: [N x 110] -> transpose -> [110 x N] -> reshape -> [110 1 1 N]
XCal4D  = reshape(XCal',  [110, 1, 1, size(XCal, 1)]);
XTest4D = reshape(XTest', [110, 1, 1, size(XTest,1)]);

% Ensure column vector for YTest
YTest = YTest(:);

%% === 9) Save prepared PTQ data ===
outFile = 'prepared_data_for_ptq.mat';
save(outFile, 'XCal4D', 'XTest4D', 'YTest', ...
              'calIdx', 'testIdx', 'validMask', ...
              'inputNames', 'outputName');

fprintf('Saved: %s\n', outFile);
fprintf('  XCal4D : [%d %d %d %d]\n', size(XCal4D));
fprintf('  XTest4D: [%d %d %d %d]\n', size(XTest4D));
fprintf('  YTest  : [%d %d]\n', size(YTest,1), size(YTest,2));

%% === 10) Quick sanity plot (optional) ===
figure;
histogram(YTest, 80);
title('YTest (normalized) distribution for PTQ eval');
xlabel('normalized uwb\_tdoA\_now\_gt');
ylabel('count');

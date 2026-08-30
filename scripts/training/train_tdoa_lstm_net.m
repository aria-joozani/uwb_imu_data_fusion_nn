%% train_tdoa_net.m
% Neural network to learn TDOA offset correction from IMU and UWB data

clc; clear; close all;
projectRoot = setup_project();

%% === Load and Prepare Data ===
% Replace this with your actual dataset file
%csvFile = '..\dataSet\flight-dataset\csv-data\const1\const1-trial1-tdoa2_NN.csv';
%data_set = readtable(csvFile);

% Initialize variables
% List of CSV files
csvFiles = {
    'export-data-set\const1-trial1-tdoa2_NN.csv';
    'export-data-set\const1-trial2-tdoa2_NN.csv';
    'export-data-set\const1-trial3-tdoa2_NN.csv';
    'export-data-set\const1-trial4-tdoa2_NN.csv';
    'export-data-set\const1-trial5-tdoa2_NN.csv';
    'export-data-set\const1-trial6-tdoa2_NN.csv';
    'export-data-set\const2-trial1-tdoa2_NN.csv';
    'export-data-set\const2-trial2-tdoa2_NN.csv';
    'export-data-set\const2-trial3-tdoa2_NN.csv';
    'export-data-set\const2-trial4-tdoa2_NN.csv';
    'export-data-set\const2-trial5-tdoa2_NN.csv';
    'export-data-set\const2-trial6-tdoa2_NN.csv';
    'export-data-set\const3-trial1-tdoa2_NN.csv';
    'export-data-set\const3-trial2-tdoa2_NN.csv';
    'export-data-set\const3-trial3-tdoa2_NN.csv';
    'export-data-set\const3-trial4-tdoa2_NN.csv';
    'export-data-set\const3-trial5-tdoa2_NN.csv';
    'export-data-set\const3-trial6-tdoa2_NN.csv';
    'export-data-set\const3-trial7-tdoa2-manual1_NN.csv';
    'export-data-set\const3-trial7-tdoa2-manual2_NN.csv';
    'export-data-set\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial1-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial1-tdoa2-traj2_NN.csv';
    'export-data-set\const4-trial1-tdoa2-traj3_NN.csv';
    'export-data-set\const4-trial2-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial2-tdoa2-traj2_NN.csv';
    'export-data-set\const4-trial2-tdoa2-traj3_NN.csv';
    'export-data-set\const4-trial3-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial3-tdoa2-traj2_NN.csv';
    'export-data-set\const4-trial3-tdoa2-traj3_NN.csv';
    'export-data-set\const4-trial4-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial4-tdoa2-traj2_NN.csv';
    'export-data-set\const4-trial4-tdoa2-traj3_NN.csv';
    'export-data-set\const4-trial6-tdoa2-traj1_NN.csv';
    'export-data-set\const4-trial6-tdoa2-traj2_NN.csv';
    'export-data-set\const4-trial6-tdoa2-traj3_NN.csv';
    'export-data-set\const4-trial7-tdoa2-manual1_NN.csv';
    'export-data-set\const4-trial7-tdoa2-manual2_NN.csv';
    'export-data-set\const4-trial7-tdoa2-manual3_NN.csv';
};

csvFiles = cellfun(@(p) fullfile(projectRoot, p), csvFiles, 'UniformOutput', false);
numFiles = length(csvFiles);
rowCounts = zeros(numFiles, 1);

fig1 = uifigure('Name','import dataset...','Position',[500 400 400 120]);
d1 = uiprogressdlg(fig1, ...
    'Title','import dataset', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

% First pass: read row counts
for i = 1:numFiles
    if mod(i, round(numFiles*2/100)) == 0  % update every 1% of progress
        d1.Value = i/(numFiles*2);
        d1.Message = sprintf('Progress: %d%% completed', round(100*i/(numFiles*2)));
        drawnow limitrate;  % more efficient refresh
    end
    info = readtable(csvFiles{i});
    rowCounts(i) = height(info);
end

% Total number of rows
totalRows = sum(rowCounts);

% Read the first table to get variable names and types
firstTable = readtable(csvFiles{1});
varNames = firstTable.Properties.VariableNames;
varTypes = varfun(@class, firstTable, 'OutputFormat', 'cell');

% Preallocate empty table with correct size and types
data_set = table('Size', [totalRows, numel(varNames)], ...
                 'VariableTypes', varTypes, ...
                 'VariableNames', varNames);

% Second pass: fill the preallocated table
rowStart = 1;



for i = 1:numFiles
    if mod((i+numFiles), round(numFiles*2/100)) == 0  % update every 1% of progress
        d1.Value = (i+numFiles)/(numFiles*2);
        d1.Message = sprintf('Progress: %d%% completed', round(100*(i+numFiles)/(numFiles*2)));
        drawnow limitrate;  % more efficient refresh
    end
    currentTable = readtable(csvFiles{i});
    rowEnd = rowStart + height(currentTable) - 1;
    data_set(rowStart:rowEnd, :) = currentTable;
    rowStart = rowEnd + 1;
end

% The variable 'data_set' now contains the data from all six CSV files appended together.

% Feature names (inputs)
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

%% Load and prepare data for LSTM
X = table2array(data_set(:, inputNames));
Y = table2array(data_set(:, outputName));

% Remove NaN rows
validMask = all(~isnan(X),2) & ~isnan(Y);
X = X(validMask,:);
Y = Y(validMask);

% Normalize data (z-score)
[X, muX, sigmaX] = zscore(X);
[Y, muY, sigmaY] = zscore(Y);

% Reshape X into sequences: [features × timeSteps × observations]
% Assuming each row is a time step and you want to create sequences of fixed length
sequenceLength = 20;  % You can adjust this
numSamples = floor(size(X,1) / sequenceLength);

X = reshape(X(1:numSamples*sequenceLength, :)', size(X,2), sequenceLength, []);
Y = reshape(Y(1:numSamples*sequenceLength), sequenceLength, []);
Y = squeeze(mean(Y, 1));  % One target per sequence

%% === 2. Split Dataset for LSTM ===
N = size(X, 3);  % Number of sequences
trainRatio = 0.7;
valRatio   = 0.15;

Ntrain = floor(trainRatio * N);
Nval   = floor(valRatio * N);
Ntest  = N - Ntrain - Nval;

% Preserve sequence order — no shuffling
XTrain = squeeze(num2cell(X(:, :, 1:Ntrain), [1 2]))';
YTrain = Y(1:Ntrain);

XValid = squeeze(num2cell(X(:, :, Ntrain+1:Ntrain+Nval), [1 2]))';
YValid = Y(Ntrain+1:Ntrain+Nval);

XTest  = squeeze(num2cell(X(:, :, Ntrain+Nval+1:end), [1 2]))';
YTest  = Y(Ntrain+Nval+1:end);

% Ensure column vectors for targets
YTrain = YTrain(:);
YValid = YValid(:);
YTest  = YTest(:);

%% === 6. Clear Unused Data ===
clear currentTable data_set firstTable info X Y

%% === 3. Define Light LSTM Architecture ===
layers = [
    sequenceInputLayer(110, "Name", "input")  % 110 features per time step

    lstmLayer(100, "OutputMode", "last", "Name", "lstm1")  % 100 hidden units
    fullyConnectedLayer(64, "Name", "fc1")
    reluLayer("Name", "relu1")

    fullyConnectedLayer(32, "Name", "fc2")
    reluLayer("Name", "relu2")

    fullyConnectedLayer(1, "Name", "output_fc")
    regressionLayer("Name", "regressionoutput")
];

%% === 4. Training Options ===
options = trainingOptions('adam', ...
    'MaxEpochs', 50, ...
    'MiniBatchSize', 128, ...  % Smaller batch size for sequence data
    'InitialLearnRate', 1e-3, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.5, ...
    'LearnRateDropPeriod', 10, ...
    'ValidationData', {XValid, YValid}, ...
    'ValidationFrequency', 30, ...
    'ValidationPatience', 10, ...
    'Shuffle', 'never', ...  % Preserve sequence order
    'Plots', 'training-progress', ...
    'Verbose', true, ...
    'ExecutionEnvironment', 'auto');

%% === 5. Train the Network ===
net = trainNetwork(XTrain, YTrain, layers, options);

%% === 6. Evaluate ===

% Predict using LSTM
YPred = predict(net, XTest);

% Reverse z-score normalization
YPred_real = YPred * sigmaY + muY;
YTest_real = YTest * sigmaY + muY;

% Compute RMSE
rmse = sqrt(mean((YPred_real - YTest_real).^2));
fprintf('Test RMSE: %.6f\n', rmse);

% Plot results
figure;
plot(YTest_real(:), 'b');
hold on;
plot(YPred_real(:), 'r');
legend('True', 'Predicted');
title('LSTM Regression Results');
xlabel('Sample');
ylabel('uwb\_tdoA\_now\_gt');

%% === Save Results ===
save(fullfile(projectRoot, 'models', 'legacy', 'trained_tdoa_net_lstm.mat'), ...
    'net', 'muX', 'sigmaX', 'muY', 'sigmaY');

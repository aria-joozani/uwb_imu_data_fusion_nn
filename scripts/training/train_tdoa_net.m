%% train_tdoa_net.m
% Neural network to learn TDOA offset correction from IMU and UWB data

clc; clear; close all;
projectRoot = setup_project();

%% === Load and Prepare Data ===
% Replace this with your actual dataset file
%csvFile = '..\dataSet\flight-dataset\csv-data\const1\const1-trial1-tdoa2_NN.csv';
%data_set = readtable(csvFile);

% List of CSV files
csvFiles = {
    '..\dataSet\flight-dataset\csv-data\const1\const1-trial1-tdoa2_NN.csv';
    '..\dataSet\flight-dataset\csv-data\const1\const1-trial2-tdoa2_NN.csv';
    '..\dataSet\flight-dataset\csv-data\const1\const1-trial3-tdoa2_NN.csv';
    '..\dataSet\flight-dataset\csv-data\const1\const1-trial4-tdoa2_NN.csv';
    '..\dataSet\flight-dataset\csv-data\const1\const1-trial5-tdoa2_NN.csv';
    '..\dataSet\flight-dataset\csv-data\const1\const1-trial6-tdoa2_NN.csv'
};

% Initialize an empty table to hold all the data
csvFiles = cellfun(@(p) fullfile(projectRoot, p), csvFiles, 'UniformOutput', false);
data_set = table();

% Loop through each file, read it, and append it to the data_set
for i = 1:length(csvFiles)
    % Read the current CSV file into a temporary table
    currentTable = readtable(csvFiles{i});
    
    % Append the temporary table to the main data_set
    % The 'vertcat' function (or simply using [data_set; currentTable]) is used
    % to stack tables vertically, assuming they have the same columns.
    data_set = vertcat(data_set, currentTable);
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

%% Extract input/output
X = table2array(data_set(:, inputNames));
Y = table2array(data_set(:, outputName));

% Remove NaNs
validMask = all(~isnan(X),2) & ~isnan(Y);
X = X(validMask, :);
Y = Y(validMask);

%% Normalize
[X, muX, sigmaX] = zscore(X);
[Y, muY, sigmaY] = zscore(Y);

%% Split into Train / Validation / Test
N = size(X,1);
idx = randperm(N);

trainRatio = 0.7;      % 70% training
validRatio = 0.15;     % 15% validation
testRatio  = 0.15;     % 15% testing

Ntrain = round(trainRatio * N);
Nvalid = round(validRatio * N);

XTrain = X(idx(1:Ntrain), :);
YTrain = Y(idx(1:Ntrain), :);

XValid = X(idx(Ntrain+1 : Ntrain+Nvalid), :);
YValid = Y(idx(Ntrain+1 : Ntrain+Nvalid), :);

XTest  = X(idx(Ntrain+Nvalid+1 : end), :);
YTest  = Y(idx(Ntrain+Nvalid+1 : end), :);

%% Optional sanity check
fprintf('Train: %d | Validation: %d | Test: %d samples\n', ...
    size(XTrain,1), size(XValid,1), size(XTest,1));
%% === Define Neural Network Architecture ===
numFeatures = size(X,2);
numResponses = size(Y,2);

layers = [
    featureInputLayer(numFeatures, 'Normalization', 'none')
    fullyConnectedLayer(512, "Name", "fc1")
    tanhLayer("Name", "tanh1")
    fullyConnectedLayer(256, "Name", "fc2")
    tanhLayer("Name", "tanh2")
    fullyConnectedLayer(128, "Name", "fc3")
    tanhLayer("Name", "tanh3")
    dropoutLayer("Name", "drupout")
    fullyConnectedLayer(64, "Name", "fc4")
    tanhLayer("Name", "tanh4")
    fullyConnectedLayer(32, "Name", "fc5")
    tanhLayer("Name", "tanh5")
    fullyConnectedLayer(numResponses, "Name", "output")
    regressionLayer("Name", "regressionoutput")
];

%% === Training Options ===
% options = trainingOptions('adam', ...
%     'MaxEpochs', 100, ...
%     'MiniBatchSize', 512, ...
%     'InitialLearnRate', 1e-3, ...
%     'Shuffle', 'every-epoch', ...
%     'Verbose', true, ...
%     'Plots', 'training-progress', ...
%     'ExecutionEnvironment', 'auto', ...
%     'OutputFcn', @(info)logTraining(info));

options = trainingOptions("adam", ...
    "InitialLearnRate", 1e-2, ...
    "MaxEpochs", 40, ...
    "MiniBatchSize", 256, ...
    "Shuffle", "every-epoch", ...
    "Plots", "training-progress", ...
    "ValidationData", {XVal, YVal}, ...
    "ValidationFrequency", 100, ...
    "Verbose", true, ...
    'OutputFcn', @(info)logTraining(info));
%% === Train Network ===
net = trainNetwork(XTrain, YTrain, layers, options);

%% === Evaluate ===
YPred = predict(net, XTest);
testMetrics = calculate_tdoa_metrics(YTest, YPred);
rmse = testMetrics.RMSE;
fprintf('Test RMSE: %.6f\n', rmse);

%% === Save Results ===
save(fullfile(projectRoot, 'models', 'active', 'trained_tdoa_net_5.mat'), ...
    'net', 'muX', 'sigmaX', 'muY', 'sigmaY');

%% === predict denoised uwb data 
%%uwb_predect = predict(net, X);

%%uwb_predect = uwb_predect .* sigmaY + muY;

%%save('uwb_predict.mat', 'uwb_predect');
%% === Log Function (to CSV) ===
function stop = logTraining(info)
    stop = false;
    if info.State == "iteration" && ~isempty(info.TrainingLoss)
        root = setup_project();
        logDir = fullfile(root, 'local-artifacts', 'logs');
        if ~isfolder(logDir)
            mkdir(logDir);
        end
        fid = fopen(fullfile(logDir, 'training_log.csv'),'a');
        fprintf(fid, '%d,%.6f\n', info.Iteration, info.TrainingLoss);
        fclose(fid);
    end
end

%% train_tdoa_net.m
% Neural network to learn TDOA offset correction from IMU and UWB data

clc; clear; close all;

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

%% Load and prepare data
X = table2array(data_set(:, inputNames));
Y = table2array(data_set(:, outputName));

% Remove NaN rows
validMask = all(~isnan(X),2) & ~isnan(Y);
X = X(validMask,:);
Y = Y(validMask);

% Normalize data (z-score)
[X, muX, sigmaX] = zscore(X);
[Y, muY, sigmaY] = zscore(Y);

%% === 2. Split Dataset ===
N = size(X,1);
idx = randperm(N);
% idx = 1:N;
trainRatio = 0.7;
valRatio   = 0.15;

Ntrain = floor(trainRatio * N);
Nval   = floor(valRatio * N);
Ntest  = N - Ntrain - Nval;

XTrain = X(idx(1:Ntrain), :);
YTrain = Y(idx(1:Ntrain), :);
XValid = X(idx(Ntrain+1:Ntrain+Nval), :);
YValid = Y(idx(Ntrain+1:Ntrain+Nval), :);
XTest  = X(idx(Ntrain+Nval+1:end), :);
YTest  = Y(idx(Ntrain+Nval+1:end), :);

% Make sure counts match
assert(size(XTrain,1) == size(YTrain,1), 'Train size mismatch');
assert(size(XValid,1) == size(YValid,1), 'Validation size mismatch');
assert(size(XTest,1)  == size(YTest,1),  'Test size mismatch');

% X: N×110 (samples × features)
XTrain = XTrain';   % Now 110×Ntrain
YTrain = YTrain';   % 1×Ntrain
XValid = XValid';   % 110×Nvalid
YValid = YValid';   % 1×Nvalid
XTest  = XTest';    % 110×Ntest
YTest  = YTest';    % 1×Ntest

XTrain4D = reshape(XTrain, [110, 1, 1, size(XTrain, 2)]);
XValid4D = reshape(XValid, [110, 1, 1, size(XValid, 2)]);
XTest4D  = reshape(XTest,  [110, 1, 1, size(XTest, 2)]);

YTrain = YTrain(:);  % Ensure column vector
YValid = YValid(:);
YTest  = YTest(:);
%% === 3. Define Light CNN Architecture ===
layers = [
    imageInputLayer([110 1 1],'Name','input','Normalization','none')  % Treat features as 1D image

    convolution2dLayer([5 1], 32, 'Padding','same', 'Name','conv1')   % 5-feature filter
    batchNormalizationLayer('Name','bn1')
    reluLayer('Name','relu1')

    maxPooling2dLayer([2 1], 'Stride',[2 1], 'Name','pool1')

    convolution2dLayer([3 1], 64, 'Padding','same', 'Name','conv2')
    batchNormalizationLayer('Name','bn2')
    reluLayer('Name','relu2')

    fullyConnectedLayer(32, "Name", "fc1")
    reluLayer("Name", "relu5")
    
    fullyConnectedLayer(1, "Name", "output_fc")
    regressionLayer("Name", "regressionoutput")
];

%% === 4. Training Options ===
options = trainingOptions("adam", ...
    "ExecutionEnvironment", "auto", ...      % uses GPU if available
    "MaxEpochs", 300, ...
    "MiniBatchSize", 1024, ...
    "InitialLearnRate", 1e-3, ...
    "ValidationData", {XValid4D, YValid}, ...
    "ValidationFrequency", 50, ...
    "Plots", "training-progress", ...
    "Verbose", true);

%% === 5. Train the Network ===
net = trainNetwork(XTrain4D, YTrain, layers, options);

%% === 6. Evaluate ===
% xTest_1 = XTest(:,110);
% xTest_1 = xTest_1';
% xTest_1 = (xTest_1 - muX') ./ sigmaX';
% % XTest = (XTest - muX') ./ sigmaX';
YPred = predict(net, XTest4D);

% Reverse z-score normalization
YPred_real = YPred * sigmaY + muY;
YTest_real = YTest * sigmaY + muY;
% Compute performance
rmse = sqrt(mean((YPred_real - YTest_real).^2));
fprintf('Test RMSE: %.6f\n', rmse);

figure;
plot(YTest_real(:), 'b');
hold on;
plot(YPred_real(:), 'r');
legend('True', 'Predicted');
title('CNN Regression Results');
xlabel('Sample');
ylabel('uwb\_tdoA\_now\_gt');

%% === Save Results ===
save('trained_tdoa_net_cnn_2.mat', 'net', 'muX', 'sigmaX', 'muY', 'sigmaY');
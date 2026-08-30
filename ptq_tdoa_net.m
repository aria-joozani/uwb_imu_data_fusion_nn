%% ptq_tdoa_net.m
% Post-Training Quantization (PTQ) for a saved trainNetwork model.
% Assumes you saved: net, muX, sigmaX, muY, sigmaY
% and that you can provide calibration + test data in the same input shape.

clc; clear; close all;

%% === 1) Load trained network ===
inFile = 'trained_tdoa_net_cnn_2.mat';
S = load(inFile, 'net', 'muX', 'sigmaX', 'muY', 'sigmaY');
net    = S.net;
muX    = S.muX;    %#ok<NASGU>  % kept if you want to normalize here
sigmaX = S.sigmaX; %#ok<NASGU>
muY    = S.muY;
sigmaY = S.sigmaY;

fprintf('Loaded: %s\n', inFile);
disp(net);

%% === 2) Load / provide representative CALIBRATION + TEST inputs ===
% IMPORTANT:
% - Calibration data must match real inference distribution.
% - Shapes must match your network input: [110 1 1 N]
%
% Option A: If you already saved prepared arrays, load them:
%   load('prepared_data.mat','XCal4D','XTest4D','YTest');
%
% Option B: If you only have raw feature matrix X (N x 110),
% you must normalize exactly like training then reshape:
%
%   X = (X - muX) ./ sigmaX;
%   X4D = reshape(X', [110 1 1 size(X,1)]);

load('prepared_data_for_ptq.mat', 'XCal4D', 'XTest4D', 'YTest');  % <-- you provide this file

% Basic checks
assert(ndims(XCal4D) == 4 && size(XCal4D,1)==110 && size(XCal4D,2)==1 && size(XCal4D,3)==1, ...
    'XCal4D must be [110 1 1 N]');
assert(ndims(XTest4D) == 4 && size(XTest4D,1)==110 && size(XTest4D,2)==1 && size(XTest4D,3)==1, ...
    'XTest4D must be [110 1 1 N]');
assert(size(YTest,1) == size(XTest4D,4), 'YTest length must match XTest4D samples');

%% === 3) Baseline FP32 evaluation (for comparison) ===
YPred_fp32 = predict(net, XTest4D);

YPred_fp32_real = YPred_fp32 * sigmaY + muY;
YTest_real      = YTest(:)    * sigmaY + muY;

rmse_fp32 = sqrt(mean((YPred_fp32_real(:) - YTest_real(:)).^2));
fprintf('FP32 Test RMSE: %.6f\n', rmse_fp32);

%% === 4) PTQ: Create quantizer, prepare, calibrate, quantize ===
% ExecutionEnvironment options depend on your target.
% Start with "MATLAB" for generic fixed-point simulation.
execEnv = "MATLAB";

quantObj = dlquantizer(net, ExecutionEnvironment=execEnv);

% Recommended: insert observers / prepare graph
quantObj = prepareNetwork(quantObj);

% Build calibration batches as a cell array
numCal = size(XCal4D, 4);
calBatchSize = 256;
numBatches = ceil(numCal / calBatchSize);
calData = cell(numBatches, 1);

for b = 1:numBatches
    i1 = (b-1)*calBatchSize + 1;
    i2 = min(b*calBatchSize, numCal);
    calData{b} = XCal4D(:,:,:,i1:i2);
end

% Run calibration (collect activation ranges)
calResults = calibrate(quantObj, calData);

% Convert to quantized network
qNet = quantize(quantObj);

%% === 5) Evaluate INT8 PTQ network ===
YPred_int8 = localPredictQuantized(qNet, XTest4D, 2048);

YPred_int8_real = YPred_int8 * sigmaY + muY;

rmse_int8 = sqrt(mean((YPred_int8_real(:) - YTest_real(:)).^2));
fprintf('INT8 PTQ Test RMSE: %.6f\n', rmse_int8);

%% === 6) Plot comparison ===
figure;
plot(YTest_real(:), 'b'); hold on;
plot(YPred_fp32_real(:), 'r');
plot(YPred_int8_real(:), 'g');
legend('True', 'FP32', 'INT8 PTQ');
title('TDOA Net: FP32 vs INT8 PTQ');
xlabel('Sample');
ylabel('uwb\_tdoA\_now\_gt');

%% === 7) Save quantized artifacts ===
outFile = 'trained_tdoa_net_cnn_2_INT8_PTQ.mat';
save(outFile, 'net', 'qNet', 'quantObj', 'calResults', ...
    'muY', 'sigmaY', 'muX', 'sigmaX', 'rmse_fp32', 'rmse_int8');
fprintf('Saved PTQ model: %s\n', outFile);

%% ===== Helper: predict for quantized network =====
function YPred = localPredictQuantized(qNet, X4D, batchSize)
    N = size(X4D, 4);
    YPred = zeros(N, 1, 'single');

    numB = ceil(N / batchSize);
    for b = 1:numB
        i1 = (b-1)*batchSize + 1;
        i2 = min(b*batchSize, N);

        xBatch = single(X4D(:,:,:,i1:i2));
        dlX = dlarray(xBatch, "SSCB");

        dlY = predict(qNet, dlX);
        y = extractdata(dlY);

        YPred(i1:i2) = reshape(single(y), [], 1);
    end
end

% Load trained network
load('trained_tdoa_net_cnn_2.mat');   % change variable name if needed
% net = trainedNet;                     % <-- your network variable

% Input size (VERY IMPORTANT)
inputSize = net.Layers(1).InputSize;

% Dummy input for shape inference
dummyInput = rand(inputSize, 'single');

% Export to ONNX
exportONNXNetwork(net, ...
    'tdoa_net.onnx', ...
    'InputDataFormats', 'BC', ...   % CNN: Batch x Channel (change if needed)
    'OutputDataFormats', 'BC');

disp('ONNX export done ✔');

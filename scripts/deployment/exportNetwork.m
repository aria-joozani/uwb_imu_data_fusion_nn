% Load trained network
projectRoot = setup_project();
load(fullfile(projectRoot, 'models', 'active', 'trained_tdoa_net_cnn_2.mat'));
% net = trainedNet;                     % <-- your network variable

% Input size (VERY IMPORTANT)
inputSize = net.Layers(1).InputSize;

% Dummy input for shape inference
dummyInput = rand(inputSize, 'single');

% Export to ONNX
outputDir = fullfile(projectRoot, 'local-artifacts', 'intermediates');
if ~isfolder(outputDir)
    mkdir(outputDir);
end
exportONNXNetwork(net, ...
    fullfile(outputDir, 'tdoa_net.onnx'), ...
    'InputDataFormats', 'BC', ...   % CNN: Batch x Channel (change if needed)
    'OutputDataFormats', 'BC');

disp('ONNX export done ✔');

%% Load and preprocess one experiment while preserving legacy aliases
projectRoot = setup_project();

disp("Load and preprocess raw sensor data...");
pipelineOverrides = struct();
pipelineOverrides.dataset = struct( ...
    'csvFile', csv_file, ...
    'anchorFile', anchors, ...
    'includeRawTable', true);
pipelineConfig = load_experiment_config( ...
    'legacy_pipeline', pipelineOverrides);

dataset = load_experiment_dataset(pipelineConfig);
synchronized = synchronize_sensor_data(dataset, pipelineConfig);
processed = preprocess_sensor_data(synchronized, pipelineConfig);

% Legacy aliases retained for dataset generation and inference scripts.
data = dataset.rawTable;
positions = dataset.anchors.positions;
quaternions = dataset.anchors.quaternions;
anchor_names = dataset.anchors.names;
anchor_position = positions;
gt_pose = dataset.groundTruth.pose;
acc = dataset.imu.accelerometer;
gyr = dataset.imu.gyroscope;
anchor_name = dataset.metadata.constellationName;
csv_name = dataset.metadata.flightName;

t_vicon = processed.timestamps.groundTruth;
pos_vicon = processed.groundTruth.position;
t_imu = processed.timestamps.imu;
imu = processed.imu.samples;
tdoa = synchronized.uwb.tdoa;
min_t = synchronized.metadata.commonTimeOrigin;
tdoa_all = processed.uwb.tdoaAll;
t_uwb = processed.timestamps.uwb;
uwb = processed.uwb.measurements;
gt_data = processed.groundTruth.atUwb;
tdoa_sim = processed.uwb.idealTdoa;
uwb_sim = processed.uwb.idealMeasurements;
t_uwb_sim = processed.timestamps.idealTdoa;

fprintf('\nSelecting anchor constellation: %s\n', anchor_name);
fprintf('ESKF estimation with: %s\n\n', csv_name);

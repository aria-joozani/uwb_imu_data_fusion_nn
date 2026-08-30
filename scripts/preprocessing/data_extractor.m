%% Load one experiment and preserve the legacy workspace interface
projectRoot = setup_project();

disp("Starting dataset load and synchronization...");
disp("Load raw sensor streams and anchor survey...");
loaderConfig = struct();
loaderConfig.dataset = struct( ...
    'csvFile', csv_file, ...
    'anchorFile', anchors, ...
    'includeRawTable', true);
dataset = load_experiment_dataset(loaderConfig);

% Legacy aliases retained for the stateful downstream scripts.
data = dataset.rawTable;
positions = dataset.anchors.positions;
quaternions = dataset.anchors.quaternions;
anchor_names = dataset.anchors.names;
anchor_position = positions;
gt_pose = dataset.groundTruth.pose;
tdoa = dataset.uwb.tdoa;
acc = dataset.imu.accelerometer;
gyr = dataset.imu.gyroscope;
anchor_name = dataset.metadata.constellationName;
csv_name = dataset.metadata.flightName;

fprintf('\nSelecting anchor constellation: %s\n', anchor_name);
fprintf('ESKF estimation with: %s\n\n', csv_name);

t_vicon = gt_pose(:,1); pos_vicon = gt_pose(:,2:4);
t_imu = acc(:,1);

%% Interpolate gyro to match accelerometer timestamps
disp("Interpolate gyro to match accelerometer timestamps...");
gyr_x_syn = interp_meas(gyr(:,1), gyr(:,2), t_imu);
gyr_y_syn = interp_meas(gyr(:,1), gyr(:,3), t_imu);
gyr_z_syn = interp_meas(gyr(:,1), gyr(:,4), t_imu);
imu = [acc(:,2:4), gyr_x_syn, gyr_y_syn, gyr_z_syn];

min_t = min([tdoa(1,1), t_imu(1), t_vicon(1)]);
idx = find(t_vicon > min_t);
t_vicon = t_vicon(idx) - min_t;
pos_vicon = pos_vicon(idx,:);

t_imu = t_imu - min_t;
tdoa(:,1) = tdoa(:,1) - min_t;

%% Downsample
disp("Downsample IMU data...");
t_imu = downsamp(t_imu);
imu = downsamp(imu);

%% Extract and downsample TDoA measurements
disp("Extract and downsample TDoA measurements...");
[tdoa_70, tdoa_01, tdoa_12, tdoa_23, tdoa_34, tdoa_45, tdoa_56, tdoa_67] = ...
    extract_tdoa_meas(tdoa(:,1), tdoa(:,2:4));
tdoa_all = [downsamp(tdoa_70); downsamp(tdoa_01); ...
    downsamp(tdoa_12); downsamp(tdoa_23); downsamp(tdoa_34); ...
    downsamp(tdoa_45); downsamp(tdoa_56); downsamp(tdoa_67)];
tdoa_all = sortrows(tdoa_all, 1);
t_uwb = tdoa_all(:,1);
uwb = tdoa_all(:,2:4);

%% Generate time difference of arrival from ground-truth data
disp("Generate time difference of arrival from ground-truth data...");
s_x_interp = interp1(t_vicon, pos_vicon(:,1), t_uwb, 'spline');
s_y_interp = interp1(t_vicon, pos_vicon(:,2), t_uwb, 'spline');
s_z_interp = interp1(t_vicon, pos_vicon(:,3), t_uwb, 'spline');
gt_data = [t_uwb, s_x_interp(:), s_y_interp(:), s_z_interp(:)];

tdoa_sim = simulate_tdoa_sequence_from_gt( ...
    gt_data, tdoa_all(:,1:3), anchor_position);
uwb_sim = tdoa_sim(:,2:4);
t_uwb_sim = tdoa_sim(:,1);

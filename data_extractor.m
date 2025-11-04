%% add functions path and dataset file path
addpath('library');

disp("📥 Starting dataset load and synchronization...");
%% === Load anchor positions and quaternions from file ===
disp("📥 Load anchor positions and quaternions from file...");
lines = splitlines(fileread(anchors)); % or replace with actual text content
lines(cellfun(@isempty, lines)) = [];  % remove empty lines

%% Initialize matrices
disp("Initialize matrices...");
positions = NaN(8, 3);        % [x y z] per anchor
quaternions = NaN(8, 4);      % [qx qy qz qw]
anchor_names = strings(8, 1); % store anchor names

for i = 1:length(lines)
    parts = strsplit(lines{i}, ',');
    name = parts{1};
    values = str2double(parts(2:end));
    
    idx = str2double(extractBetween(name, 3, 3)) + 1;  % anchor index (0-based to 1-based)

    if contains(name, '_p')
        positions(idx, :) = values;
        anchor_names(idx) = name(1:3);  % an0, an1, ...
    elseif contains(name, '_quat')
        quaternions(idx, :) = values;
    end
end

%% Load anchor survey data
disp("Load anchor survey data...");
anchor_position = positions;

%% Print selected constellation
[~, anchor_name, ~] = fileparts(anchors);
fprintf('\nSelecting anchor constellation: %s\n', anchor_name);

%% Load CSV data
disp("Load CSV data...");
data = readtable(csv_file);
[~, csv_name, ~] = fileparts(csv_file);
fprintf('ESKF estimation with: %s\n\n', csv_name);

%% Extract measurement data
disp("Extract measurement data...");
gt_pose = extract_gt(data);
tdoa = extract_tdoa(data);
acc = extract_acc(data);
gyr = extract_gyro(data);

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

%% downsample
disp("downsample imu data...");
t_imu = downsamp(t_imu);
imu = downsamp(imu);

%% Extract and downsamplele TDOA measurements
disp("Extract and downsamplele TDOA measurements...");
[tdoa_70, tdoa_01, tdoa_12, tdoa_23, tdoa_34, tdoa_45, tdoa_56, tdoa_67] = extract_tdoa_meas(tdoa(:,1), tdoa(:,2:4));
tdoa_all = [downsamp(tdoa_70); downsamp(tdoa_01); downsamp(tdoa_12); downsamp(tdoa_23); ...
            downsamp(tdoa_34); downsamp(tdoa_45); downsamp(tdoa_56); downsamp(tdoa_67)];
tdoa_all = sortrows(tdoa_all, 1);
t_uwb = tdoa_all(:,1);
uwb = tdoa_all(:,2:4);

%% generate time diffrence of arrival from ground trouth data 
disp("generate time diffrence of arrival from ground trouth data...");
% Suppose: 
% - gt_pose: [time x y z ...]
% - anchor_position: 8x3
% - tdoa: [time idA idB tdoa_val]
%gt_data = gt_pose(:, 1:4);
s_x_interp = interp1(t_vicon, pos_vicon(:,1), t_uwb, 'spline');
s_y_interp = interp1(t_vicon, pos_vicon(:,2), t_uwb, 'spline');
s_z_interp = interp1(t_vicon, pos_vicon(:,3), t_uwb, 'spline');
gt_data = [t_uwb, s_x_interp(:), s_y_interp(:), s_z_interp(:)];

tdoa_sim = simulate_tdoa_sequence_from_gt(gt_data, tdoa_all(:,1:3), anchor_position);
%tdoa_sim = downsamp(tdoa_sim); % if nanoseconds
%[rmse, mean_err, tdoa_error] = compare_tdoa_sim_vs_meas(tdoa_sim, tdoa);
uwb_sim = tdoa_sim(:,2:4);
t_uwb_sim = tdoa_sim(:,1);
%%
clc; close all; clear all;
disp("📥 Starting dataset load and synchronization...");

csv_file = '..\dataSet\flight-dataset\csv-data\const1\const1-trial1-tdoa2.csv';
anchors = '..\dataSet\flight-dataset\survey-results\anchor_const1_survey.txt';

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
%% generate dataset
disp("generate dataset...");

%% import from network output

%% Initialize ESKF with UWB data 
disp("Initialize ESKF with UWB data...");
t = unique([t_imu; t_uwb_sim]);
K = length(t);
X0 = zeros(6,1); X0(1) = 1.25; X0(2) = 0.0; X0(3) = 0.07;
q0 = [1, 0, 0, 0]; % quaternion
std_xy0 = 0.1; std_z0 = 0.1; std_vel0 = 0.1;
std_rp0 = 0.1; std_yaw0 = 0.1;
P0 = diag([std_xy0^2, std_xy0^2, std_z0^2, std_vel0^2, std_vel0^2, std_vel0^2, ...
           std_rp0^2, std_rp0^2, std_yaw0^2]);
eskf = ESKF(X0, q0, P0, K);
fprintf('Timestep: %d\n', K);
fprintf('Start state estimation\n');

for k = 2:K
    [imu_k, imu_check] = isin(t_imu, t(k-1));
    [uwb_k, uwb_check] = isin(t_uwb, t(k-1));
    dt = t(k) - t(k-1);
    
    eskf.predict(imu(imu_k,:), dt, imu_check, k);
    if uwb_check
        eskf.UWB_correct(uwb(uwb_k,:), anchor_position, k);
    end
end
fprintf('Finish the state estimation\n');

%% Interpolate Vicon for ground truth
disp("Interpolate Vicon for ground truth...");
x_interp = interp1(t_vicon, pos_vicon(:,1), t, 'spline');
y_interp = interp1(t_vicon, pos_vicon(:,2), t, 'spline');
z_interp = interp1(t_vicon, pos_vicon(:,3), t, 'spline');
interp_gt = [x_interp(:), y_interp(:), z_interp(:)];

position_k = eskf.Xpo(:, 1:3);  % Estimated position at time k
velocity_k = eskf.Xpo(:, 4:6);  % Estimated velocity

pos_error = position_k - interp_gt;
rms_x = sqrt(mean((pos_error(:,1)).^2));
rms_y = sqrt(mean((pos_error(:,2)).^2));
rms_z = sqrt(mean((pos_error(:,3)).^2));
RMS_all = sqrt(rms_x^2 + rms_y^2 + rms_z^2);

fprintf('The RMS error for position x is %.4f m\n', rms_x);
fprintf('The RMS error for position y is %.4f m\n', rms_y);
fprintf('The RMS error for position z is %.4f m\n', rms_z);
fprintf('The overall RMS error of position estimation is %.4f m\n', RMS_all);

%% Plot results
disp("Plot results...");
plot_pos(t, eskf.Xpo, t_vicon, pos_vicon);
plot_pos_err(t, pos_error, eskf.Ppo);
plot_traj(pos_vicon, eskf.Xpo, anchor_position);

%%
function [rmse, mean_err, error_vector] = compare_tdoa_sim_vs_meas(tdoa_sim, tdoa_meas)
%COMPARE_TDOA_SIM_VS_MEAS Compare simulated TDOA with measured TDOA values.
%
% Inputs:
%   tdoa_sim  - Nx4 array: [time, idA, idB, simulated_tdoa]
%   tdoa_meas - Nx4 array: [time, idA, idB, measured_tdoa]
%
% Outputs:
%   rmse         - Root Mean Squared Error
%   mean_err     - Mean absolute error
%   error_vector - Nx1 array of signed error per row

    assert(size(tdoa_sim,1) == size(tdoa_meas,1), 'TDOA arrays must have the same length.');

    error_vector = zeros(size(tdoa_sim,1),1);
    match_count = 0;

    for i = 1:size(tdoa_sim, 1)
        % Match based on time, idA, idB
        if tdoa_sim(i,1) == tdoa_meas(i,1) && ...
           tdoa_sim(i,2) == tdoa_meas(i,2) && ...
           tdoa_sim(i,3) == tdoa_meas(i,3)

            error_vector(i) = tdoa_meas(i,4) - tdoa_sim(i,4);
            match_count = match_count + 1;
        else
            warning("Row %d: mismatch in [time, idA, idB] between simulated and measured data.", i);
        end
    end

    % Compute metrics
    rmse = sqrt(mean(error_vector.^2));
    mean_err = mean(abs(error_vector));

    fprintf("✅ TDOA comparison complete on %d matched entries\n", match_count);
    fprintf("🔹 RMSE:       %.3e mm\n", rmse*10e3);
    fprintf("🔹 Mean Error: %.3e mm\n", mean_err*10e3);
end

function tdoa_val = generate_tdoa_from_gt(tag_pos, anchor_A_pos, anchor_B_pos)
    % tag_pos: 1x3 position of tag [x y z]
    % anchor_A_pos: 1x3 position of anchor A [x y z]
    % anchor_B_pos: 1x3 position of anchor B [x y z]
    
    c = 299792458e-9; % speed of light in m/s
    d_A = norm(tag_pos - anchor_A_pos);
    d_B = norm(tag_pos - anchor_B_pos);
    
    tdoa_val = (d_B - d_A) ;
end

function tdoa_sim = simulate_tdoa_sequence_from_gt(gt_data, tdoa_tags, anchor_pos)
    % gt_data: Nx4 matrix [time x y z]
    % tdoa_tags: Mx3 matrix [time, idA, idB]
    % anchor_pos: 8x3 matrix of anchor positions

    tdoa_sim = zeros(size(tdoa_tags, 1), 4); % [time, idA, idB, tdoa_val]

    for i = 1:size(tdoa_tags, 1)
        t = tdoa_tags(i, 1);
        idA = tdoa_tags(i, 2);
        idB = tdoa_tags(i, 3);

        tag_pos = gt_data(i, 2:4);
        tdoa_val = generate_tdoa_from_gt(tag_pos, anchor_pos(idA+1, :), anchor_pos(idB+1, :));
        tdoa_sim(i, :) = [t, idA, idB, tdoa_val];
    end
end

function data_ds = downsamp(data)
    % Down-sample UWB data three times by a factor of 2
    data_ds = data;
    %data_ds = data(1:2:end, :);         % First downsample
    %data_ds = data_ds(1:2:end, :);      % Second downsample
    %data_ds = data_ds(1:2:end, :);      % Third downsample
end
function [index, found] = isin(t_np, t_k)
    idx = find(t_np == t_k, 1);
    if ~isempty(idx)
        index = idx;
        found = true;
    else
        index = 1;
        found = false;
    end
end

function new_array = deleteNAN(array)
    nan_array = isnan(array);
    not_nan = ~nan_array;
    new_array = array(not_nan);
end

function syn_m1 = interp_meas(t1, meas1, t2)
    % synchronized meas1 w.r.t. t2
    t1 = squeeze(t1);
    t2 = squeeze(t2);
    meas1 = squeeze(meas1);
    syn_m1 = interp1(t1, meas1, t2, 'linear', 'extrap');
end

function pos_s = sync_pos(t_1, pos_1, t_2)
    x_s = interp_meas(t_1, pos_1(:,1), t_2);
    y_s = interp_meas(t_1, pos_1(:,2), t_2);
    z_s = interp_meas(t_1, pos_1(:,3), t_2);
    pos_s = [x_s(:), y_s(:), z_s(:)];
end

function gt_pose = extract_gt(df)
    gt_t  = deleteNAN(df.t_pose(:));
    gt_x  = deleteNAN(df.pose_x(:));
    gt_y  = deleteNAN(df.pose_y(:));
    gt_z  = deleteNAN(df.pose_z(:));
    gt_qx = deleteNAN(df.pose_qx(:));
    gt_qy = deleteNAN(df.pose_qy(:));
    gt_qz = deleteNAN(df.pose_qz(:));
    gt_qw = deleteNAN(df.pose_qw(:));
    gt_pose = [gt_t, gt_x, gt_y, gt_z, gt_qx, gt_qy, gt_qz, gt_qw];
end

function tdoa = extract_tdoa(df)
    t_tdoa = deleteNAN(df.t_tdoa(:));
    idA = deleteNAN(df.idA(:));
    idB = deleteNAN(df.idB(:));
    tdoa_meas = deleteNAN(df.tdoa_meas(:));
    tdoa = [t_tdoa, idA, idB, tdoa_meas];
end

function acc = extract_acc(df)
    t_acc = deleteNAN(df.t_acc(:));
    acc_x = deleteNAN(df.acc_x(:));
    acc_y = deleteNAN(df.acc_y(:));
    acc_z = deleteNAN(df.acc_z(:));
    acc = [t_acc, acc_x, acc_y, acc_z];
end

function gyro = extract_gyro(df)
    t_gyro = deleteNAN(df.t_gyro(:));
    gyro_x = deleteNAN(df.gyro_x(:));
    gyro_y = deleteNAN(df.gyro_y(:));
    gyro_z = deleteNAN(df.gyro_z(:));
    gyro = [t_gyro, gyro_x, gyro_y, gyro_z];
end

function tof = extract_tof(df)
    t_tof = deleteNAN(df.t_tof(:));
    tof_meas = deleteNAN(df.tof(:));
    tof = [t_tof, tof_meas];
end

function flow = extract_flow(df)
    t_flow = deleteNAN(df.t_flow(:));
    dx = deleteNAN(df.deltaX(:));
    dy = deleteNAN(df.deltaY(:));
    flow = [t_flow, dx, dy];
end

function baro = extract_baro(df)
    t_baro = deleteNAN(df.t_baro(:));
    baro_meas = deleteNAN(df.baro(:));
    baro = [t_baro, baro_meas];
end

function [tdoa_70, tdoa_01, tdoa_12, tdoa_23, tdoa_34, tdoa_45, tdoa_56, tdoa_67] = extract_tdoa_meas(t_tdoa, tdoa_data)
    t_tdoa = t_tdoa(:);
    tdoa = [t_tdoa, tdoa_data];

    tdoa_70 = tdoa(tdoa(:,2) == 7 & tdoa(:,3) == 0, :);
    tdoa_01 = tdoa(tdoa(:,2) == 0 & tdoa(:,3) == 1, :);
    tdoa_12 = tdoa(tdoa(:,2) == 1 & tdoa(:,3) == 2, :);
    tdoa_23 = tdoa(tdoa(:,2) == 2 & tdoa(:,3) == 3, :);
    tdoa_34 = tdoa(tdoa(:,2) == 3 & tdoa(:,3) == 4, :);
    tdoa_45 = tdoa(tdoa(:,2) == 4 & tdoa(:,3) == 5, :);
    tdoa_56 = tdoa(tdoa(:,2) == 5 & tdoa(:,3) == 6, :);
    tdoa_67 = tdoa(tdoa(:,2) == 6 & tdoa(:,3) == 7, :);
end

function plot_pos(t, Xpo, t_vicon, pos_vicon)
    FONTSIZE = 18;

    figure('Color','w','Position',[100 100 800 600]);
    
    subplot(3,1,1);
    plot(t_vicon, pos_vicon(:,1), 'Color', [1 0.27 0], 'LineWidth', 2.5); hold on;
    plot(t, Xpo(:,1), 'Color', [0.25 0.41 0.88], 'LineWidth', 2.5);
    ylabel('X [m]', 'FontSize', FONTSIZE);
    title('Estimation results', 'FontSize', FONTSIZE);
    legend('Vicon ground truth', 'Estimate');
    xlim([0 max(t)]);

    subplot(3,1,2);
    plot(t_vicon, pos_vicon(:,2), 'Color', [1 0.27 0], 'LineWidth', 2.5); hold on;
    plot(t, Xpo(:,2), 'Color', [0.25 0.41 0.88], 'LineWidth', 2.5);
    ylabel('Y [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);

    subplot(3,1,3);
    plot(t_vicon, pos_vicon(:,3), 'Color', [1 0.27 0], 'LineWidth', 2.5); hold on;
    plot(t, Xpo(:,3), 'Color', [0.25 0.41 0.88], 'LineWidth', 2.5);
    xlabel('time [s]', 'FontSize', FONTSIZE);
    ylabel('Z [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);
end

function plot_pos_err(t, pos_error, Ppo)
    FONTSIZE = 18;
    if nargin < 3 || isempty(Ppo)
        Ppo = zeros(0, 9, 9);
    end

    D = size(Ppo, 1);
    delta_x = zeros(D,1);
    delta_y = zeros(D,1);
    delta_z = zeros(D,1);

    for i = 1:D
        delta_x(i) = sqrt(Ppo(i,1,1));
        delta_y(i) = sqrt(Ppo(i,2,2));
        delta_z(i) = sqrt(Ppo(i,3,3));
    end

    figure('Color','w','Position',[100 100 800 600]);

    subplot(3,1,1);
    title('Estimation Error', 'FontSize', FONTSIZE);
    plot(t, pos_error(:,1), 'Color', [0.27 0.51 0.71], 'LineWidth', 2); hold on;
    fill([t; flipud(t)], [3*delta_x; flipud(-3*delta_x)], ...
         'c', 'FaceAlpha', 0.3, 'EdgeColor','none');
    ylabel('error x [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);
    ylim([-0.35, 0.35]);

    subplot(3,1,2);
    plot(t, pos_error(:,2), 'Color', [0.27 0.51 0.71], 'LineWidth', 2); hold on;
    fill([t; flipud(t)], [3*delta_y; flipud(-3*delta_y)], ...
         'c', 'FaceAlpha', 0.3, 'EdgeColor','none');
    ylabel('error y [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);
    ylim([-0.35, 0.35]);

    subplot(3,1,3);
    plot(t, pos_error(:,3), 'Color', [0.27 0.51 0.71], 'LineWidth', 2); hold on;
    fill([t; flipud(t)], [3*delta_z; flipud(-3*delta_z)], ...
         'c', 'FaceAlpha', 0.3, 'EdgeColor','none');
    xlabel('time [s]', 'FontSize', FONTSIZE);
    ylabel('error z [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);
    ylim([-0.45, 0.45]);
end

function plot_traj(pos_vicon, Xpo, anchor_pos)
    FONTSIZE = 18;
    figure('Color','w','Position',[100 100 800 600]);
    %ax = axes('Projection','3d');

    hold on;
    plot3(pos_vicon(:,1), pos_vicon(:,2), pos_vicon(:,3), 'b', 'LineWidth', 2);
    plot3(Xpo(:,1), Xpo(:,2), Xpo(:,3), 'g', 'LineWidth', 3);
    scatter3(anchor_pos(:,1), anchor_pos(:,2), anchor_pos(:,3), ...
             100, 'filled', 'MarkerFaceColor', [0 0.5 0.5], 'MarkerEdgeAlpha',0.5);

    xlim([-3.5, 3.5]);
    ylim([-3.9, 3.9]);
    zlim([0, 3.0]);
    xlabel('X [m]', 'FontSize', FONTSIZE);
    ylabel('Y [m]', 'FontSize', FONTSIZE);
    zlabel('Z [m]', 'FontSize', FONTSIZE);
    legend('ground truth', 'estimation', 'anchors', 'FontSize', FONTSIZE, 'Location', 'best');

    view(24, -58);
    daspect([1 1 0.5]);
end

clc; close all; clear all;
csv_file = 'csv-data\const4\const4-trial7-tdoa2-manual3.csv';
anchors = 'survey-results\anchor_const4_survey.txt';
outDir = 'result\const4-trial7-tdoa2-manual3\eskf';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
diary([outDir  '\eskf.txt']);
diary on
data_extractor;
%% Initialize ESKF with UWB data 
disp("Initialize ESKF with UWB data...");

fig1 = uifigure('Name','simulate the trajectory...','Position',[500 400 400 120]);
d1 = uiprogressdlg(fig1, ...
    'Title','simulate the trajectory', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

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
    if mod(k, round(K/100)) == 0  % update every 1% of progress
        d1.Value = k/K;
        d1.Message = sprintf('Progress: %d%% completed', round(100*k/K));
        drawnow limitrate;  % more efficient refresh
    end
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

ma_x  = mean(abs(pos_error(:,1)));
ma_y  = mean(abs(pos_error(:,2)));
ma_z  = mean(abs(pos_error(:,3)));
ma_all  = mean(abs(ma_x) + abs(ma_y) + abs(ma_x));

fprintf('The RMS error for position x is %.4f m\n', rms_x);
fprintf('The RMS error for position y is %.4f m\n', rms_y);
fprintf('The RMS error for position z is %.4f m\n', rms_z);
fprintf('The overall RMS error of position estimation is %.4f m\n', RMS_all);

fprintf('The MA error for position x is %.4f m\n', ma_x);
fprintf('The MA error for position y is %.4f m\n', ma_y);
fprintf('The MA error for position z is %.4f m\n', ma_z);
fprintf('The overall Ma error of position estimation is %.4f m\n', ma_all);
%% Plot results
disp("Plot results...");
plot_pos(t, eskf.Xpo, t_vicon, pos_vicon);
plot_pos_err(t, pos_error, eskf.Ppo);
plot_traj(pos_vicon, eskf.Xpo, anchor_position);
%% save figures

figs = findall(0, 'Type', 'figure');

for k = 1:length(figs)
    savefig(figs(k), fullfile(outDir, figs(k).Name));
end

diary off
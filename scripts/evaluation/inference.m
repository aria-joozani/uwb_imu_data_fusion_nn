%% load data and network
clc; close all; clear all;
projectRoot = setup_project();
trials = {
    'const4-trial1-tdoa2-traj1'
    'const4-trial1-tdoa2-traj2'
    'const4-trial1-tdoa2-traj3'
    'const4-trial2-tdoa2-traj1'
    'const4-trial2-tdoa2-traj2'
    'const4-trial2-tdoa2-traj3'
    'const4-trial3-tdoa2-traj1'
    'const4-trial3-tdoa2-traj2'
    'const4-trial3-tdoa2-traj3'
    'const4-trial4-tdoa2-traj1'
    'const4-trial4-tdoa2-traj2'
    'const4-trial4-tdoa2-traj3'
    'const4-trial5-tdoa2-traj1'
    'const4-trial5-tdoa2-traj2'
    'const4-trial5-tdoa2-traj3'
    'const4-trial6-tdoa2-traj1'
    'const4-trial6-tdoa2-traj2'
    'const4-trial6-tdoa2-traj3'
    'const4-trial7-tdoa2-manual1'
    'const4-trial7-tdoa2-manual2'
    'const4-trial7-tdoa2-manual3'
};

data = trials{11};
net = '2';

csv_file = fullfile(projectRoot, 'csv-data', 'const4', [data '.csv']);
anchors = fullfile(projectRoot, 'survey-results', 'anchor_const4_survey.txt');
% outDir = ['result\' data '\cnn_net_' net];
outDir = fullfile(projectRoot, 'result', data, 'fcc1');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
diary([outDir  '\net.txt']);
diary on
data_extractor;
modelConfig = tdoa_model_config('fnn', projectRoot);
tdoaModel = load_tdoa_correction_model(modelConfig);
%% extract and intgrate imu & uwb data 
disp("extract and intgrate imu & uwb...");
t = unique([t_imu; t_uwb_sim]);
K = length(t);

% t 1 + acc 3 + gyro 3 + UWB 3 + UWB_sim 1
integrated_dateset = nan(K, 11);

integrated_dateset(:, 1) = t;

fig1 = uifigure('Name','extract and intgrate imu & uwb...','Position',[500 400 400 120]);
d1 = uiprogressdlg(fig1, ...
    'Title','extract and intgrate imu & uwb', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);


for k = 2:K

    if mod(k, round(K/100)) == 0  % update every 1% of progress
        d1.Value = k/K;
        d1.Message = sprintf('Progress: %d%% completed', round(100*k/K));
        drawnow limitrate;  % more efficient refresh
    end

    [imu_k, imu_check] = isin(t_imu, t(k-1));
    [uwb_k, uwb_check] = isin(t_uwb_sim, t(k-1));
    dt = t(k) - t(k-1);

    if imu_check
        integrated_dateset(k , 2:7) = imu(imu_k,:);
        %%eskf.predict(imu(imu_k,:), dt, imu_check, k);
    end

    if uwb_check
        integrated_dateset(k , 8:10) = uwb(uwb_k,:);
        integrated_dateset(k , 11) = uwb_sim(uwb_k,3);
        %%eskf.UWB_correct(uwb_sim(uwb_k,:), anchor_position, k);
    end
end
close(d1);
close(fig1);
%% simulation the trajectry
disp("simulation the trajectry...");

fig2 = uifigure('Name','simulation the trajectry...','Position',[500 400 400 120]);
d2 = uiprogressdlg(fig2, ...
    'Title','simulation the trajectry', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

sreach_next_sample_window_size = 100;

max_num_of_epoch = size(uwb);
max_num_of_epoch = max_num_of_epoch(1);
number_of_interp = 17;
interp_time = zeros([number_of_interp 1]);
imu_epoch_samples_count = zeros([max_num_of_epoch 6]);
dataset_epoch_data = zeros([number_of_interp+2 6]);

uwb_enhanced = zeros([max_num_of_epoch 1]);

% uwb_enhanced(1:8) = uwb(1:8, 3);
m = 1;
for k = 2:K

    if mod(k, round(K/100)) == 0  % update every 1% of progress
        d2.Value = k/K;
        d2.Message = sprintf('Progress: %d%% completed', round(100*k/K));
        drawnow limitrate;  % more efficient refresh
    end

    if ~isnan(integrated_dateset(k, 8))
        pair_of_tag_check = integrated_dateset(k, 8);
        
        if k+sreach_next_sample_window_size > K
            sreach_next_sample = K;
        else 
            sreach_next_sample = k + sreach_next_sample_window_size;
        end
        for l = k+1:sreach_next_sample
            if integrated_dateset(l, 8) == pair_of_tag_check
                break;
            end
        end

        sample_tdoa_time =  integrated_dateset(l, 1) - integrated_dateset(k, 1);
        
        % Check for rows without any NaN
        validRows = ~isnan(integrated_dateset(k:l, 2));
        % Count them
        numValidRows = sum(validRows);
        imu_epoch_samples_count(m) = numValidRows;
        data = integrated_dateset(k:l, 1:7);
        imu_epoch_samples = data(validRows, :);
        interp_time_step_size = sample_tdoa_time/17;

        if(k == K)
            break;
        end

        for ii = 1:number_of_interp
            interp_time(ii) = integrated_dateset(k, 1) + interp_time_step_size * ii;
        end

        if numValidRows < 2
            imu_epoch_samples(2,:) = imu_epoch_samples(1,:);
            imu_epoch_samples(2,1) = imu_epoch_samples(2,1) + 0.1;
        end
        imu_epoch_samples_interp = ...
            interp1(imu_epoch_samples(:, 1), imu_epoch_samples(:, 2:7), ...
            interp_time, 'linear', 'extrap');
        %test data interpolation
        %hold
        %plot(imu_epoch_samples(:, 2))
        %plot(imu_epoch_samples_interp(:, 1))
        dataset_epoch_data(1:17, :) = imu_epoch_samples_interp;
        dataset_epoch_data(18, 1:3) = ...
            anchor_position(pair_of_tag_check+1, :);
        if pair_of_tag_check == 7
            dataset_epoch_data(18, 4:6) = ... 
                anchor_position(1, :);
        else 
            dataset_epoch_data(18, 4:6) = ... 
                anchor_position(pair_of_tag_check+2, :);
        end
        
        dataset_epoch_data(19, 1) = integrated_dateset(k, 10);
        dataset_epoch_data(19, 2) = integrated_dateset(l, 10);

        X = dataset_epoch_data;
        X = X';
        X = X(:);
        X = X(1:110);
        uwb_predict = predict_tdoa_correction(tdoaModel, X.');
        if mod(k,1) ~= 0
            integrated_dateset(l, 10) = uwb_predict;
        end        
        uwb_enhanced(m) = uwb_predict;
        m = m + 1;
        k = l;
    end
end
close(d2);
close(fig2);
%% calculate error 
% error_net = uwb_sim(:,3) - uwb_enhanced(1:max_num_of_epoch);
% error_raw = uwb_sim(:,3) - uwb(:,3);
%
% rms_raw = sqrt(mean((error_raw(:,1)).^2));
% rms_net = sqrt(mean((error_net(:,1)).^2));
% mae_raw  = mean(abs(error_raw(:,1)));
% mae_net  = mean(abs(error_net(:,1)));
%
% fprintf('The RMS error for uwb raw data is %.4f m\n', rms_raw);
% fprintf('The RMS error for uwb net data is %.4f m\n', rms_net);
%
% fprintf('The MAE error for uwb raw data is %.4f m\n', mae_raw);
% fprintf('The MAE error for uwb net data is %.4f m\n', mae_net);
% hold
% plot(error_raw)
% plot(error_net)

%% 4) TDOA error metrics + plots
% disp("Compute TDOA error metrics...");
%
% uwb_enhanced_with_pair = uwb;
% uwb_enhanced_with_pair(:,3) = uwb_enhanced(1:max_num_of_epoch);
% error_raw = uwb_sim(:,3) - uwb(:,3);
% error_net = uwb_sim(:,3) - uwb_enhanced;

%% 4) TDOA error metrics + plots (PER-PAIR)
disp("Compute TDOA error metrics (per pair) ...");

uwb_enhanced_with_pair = uwb;
uwb_enhanced_with_pair(:,3) = uwb_enhanced(1:max_num_of_epoch);

error_raw = uwb_sim(:,3) - uwb(:,3);
error_net = uwb_sim(:,3) - uwb_enhanced_with_pair(:,3);

metrics_raw = calculate_tdoa_metrics(uwb_sim(:,3), uwb(:,3));
metrics_net = calculate_tdoa_metrics( ...
    uwb_sim(:,3), uwb_enhanced_with_pair(:,3));
rms_raw = metrics_raw.RMSE;
rms_net = metrics_net.RMSE;
ma_raw = metrics_raw.MAE;
ma_net = metrics_net.MAE;

fprintf('The RMS error for uwb raw data is %.4f m\n', rms_raw);
fprintf('The RMS error for uwb net data is %.4f m\n', rms_net);

fprintf('The MAE error for uwb raw data is %.4f m\n', ma_raw);
fprintf('The MAE error for uwb net data is %.4f m\n', ma_net);
hold

% ---- overall plot (optional) ----
figure('Name','TDOA error (overall)');
plot(error_raw,'LineWidth',1); hold on;
plot(error_net,'LineWidth',1);
grid on; legend('Raw','Enhanced');
title('TDOA error (overall)'); xlabel('UWB epoch'); ylabel('Error (m)');

% ---- per-pair plots ----
pair_ids = unique(uwb(:,1))';   % pair id is in column 1

fprintf('\n=== Per-Pair TDOA Error Metrics ===\n');
for pid = pair_ids

    idx = (uwb(:,1) == pid);    % rows for this pair

    if sum(idx) < 5
        fprintf('Pair %d: skipped (too few samples: %d)\n', pid, sum(idx));
        continue;
    end

    % errors for this pair
    e_raw = error_raw(idx);
    e_net = error_net(idx);

    % metrics
    pair_metrics_raw = calculate_tdoa_metrics(e_raw, zeros(size(e_raw)));
    pair_metrics_net = calculate_tdoa_metrics(e_net, zeros(size(e_net)));
    rmse_raw = pair_metrics_raw.RMSE;
    rmse_net = pair_metrics_net.RMSE;
    mae_raw = pair_metrics_raw.MAE;
    mae_net = pair_metrics_net.MAE;

    fprintf('Pair %d: RMSE raw=%.4f, RMSE enh=%.4f | MAE raw=%.4f, MAE enh=%.4f | N=%d\n', ...
        pid, rmse_raw, rmse_net, mae_raw, mae_net, sum(idx));

    % plot (separate figure per pair)
    figure('Name',sprintf('Pair %d TDOA error', pid));
    plot(e_raw,'LineWidth',1); hold on;
    plot(e_net,'LineWidth',1);
    grid on;
    title(sprintf('TDOA Error for Pair %d', pid));
    xlabel('Sample index (within this pair)');
    ylabel('Error (m)');
    legend('Raw','Enhanced');
end

%%
uwb(:,3) = uwb_enhanced(1:max_num_of_epoch);

%% Initialize ESKF with UWB data 
disp("Initialize ESKF with UWB data...");

fig3 = uifigure('Name','fusion data...','Position',[500 400 400 120]);
d3 = uiprogressdlg(fig3, ...
    'Title','fusion data', ...
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
        d3.Value = k/K;
        d3.Message = sprintf('Progress: %d%% completed', round(100*k/K));
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

position_metrics = calculate_position_metrics(interp_gt, position_k);
pos_error = position_metrics.ERROR_XYZ;
rms_x = position_metrics.RMSE_X;
rms_y = position_metrics.RMSE_Y;
rms_z = position_metrics.RMSE_Z;
RMS_all = position_metrics.RMS_ALL;
ma_x = position_metrics.MAE_X;
ma_y = position_metrics.MAE_Y;
ma_z = position_metrics.MAE_Z;
ma_all = position_metrics.LEGACY_MA_XXY;

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

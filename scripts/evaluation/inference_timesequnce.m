%% load data and network
clc; close all; clear all;
projectRoot = setup_project();

csv_file = fullfile(projectRoot, 'csv-data', 'const4', 'const4-trial3-tdoa2-traj1.csv');
anchors  = fullfile(projectRoot, 'survey-results', 'anchor_const4_survey.txt');

data_extractor;
modelConfig = tdoa_model_config('cnn2', projectRoot);
tdoaModel = load_tdoa_correction_model(modelConfig);

%% extract and integrate imu & uwb data
disp("extract and integrate imu & uwb...");

t = unique([t_imu; t_uwb_sim]);
K = length(t);

% t 1 + acc 3 + gyro 3 + UWB 3 + UWB_sim 1
integrated_dateset = nan(K, 11);
uwb_row_at_time    = nan(K, 1);   % maps integrated time index -> row index in uwb
integrated_dateset(:, 1) = t;

fig1 = uifigure('Name','extract and integrate imu & uwb...','Position',[500 400 400 120]);
d1 = uiprogressdlg(fig1, ...
    'Title','extract and integrate imu & uwb', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

for k = 2:K

    if mod(k, max(1,round(K/100))) == 0
        d1.Value = k/K;
        d1.Message = sprintf('Progress: %d%% completed', round(100*k/K));
        drawnow limitrate;
    end

    [imu_k, imu_check] = isin(t_imu, t(k-1));
    [uwb_k, uwb_check] = isin(t_uwb_sim, t(k-1));
    % dt = t(k) - t(k-1);

    if imu_check
        integrated_dateset(k, 2:7) = imu(imu_k,:);
    end

    if uwb_check
        integrated_dateset(k, 8:10) = uwb(uwb_k,:);
        integrated_dateset(k, 11)   = uwb_sim(uwb_k,3);
        uwb_row_at_time(k) = uwb_k;
    end
end
d1.Value = 1;
d1.Message = "extract completed";
pause(1);
close(fig1);
close(d1);
%% history-chain inference + alpha filter (per-target rollout)
disp("history-chain inference (autoregressive) + alpha ...");

fig_inf = uifigure('Name','NN history-chain inference','Position',[500 400 420 130]);
d_inf = uiprogressdlg(fig_inf, ...
    'Title','Neural Network Inference', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

numOfHistory = 3;          % H
number_of_interp = 17;
if numOfHistory == 0
    alpha = 1;   % یعنی y_alpha = y (بدون فیلتر)
else
    alpha = 0.5;              % 0<alpha<=1  (پیشنهاد شروع: 0.1 تا 0.3)
end

% working copy of TDOA (committed outputs only)
tdoa_corr = integrated_dateset(:,10);

% output array aligned with uwb rows
max_num_of_epoch = size(uwb,1);
uwb_enhanced = nan(max_num_of_epoch,1);

% buffers
interp_time = zeros(number_of_interp,1);
dataset_epoch_data = zeros(number_of_interp+2, 6); % 19 x 6

pair_ids = unique(integrated_dateset(~isnan(integrated_dateset(:,8)), 8))';

% estimate total steps for progress
total_steps = 0;
for pid = pair_ids
    idxs = find(integrated_dateset(:,8) == pid);
    if numel(idxs) > 1
        total_steps = total_steps + (numel(idxs) - 1);
    end
end
step_counter = 0;

for pid = pair_ids

    idxs = find(integrated_dateset(:,8) == pid);
    if numel(idxs) < 2
        continue;
    end

    for i = 1:(numel(idxs)-1)

        step_counter = step_counter + 1;

        if mod(step_counter, max(1, round(total_steps/100))) == 0 || step_counter == total_steps
            d_inf.Value = step_counter / total_steps;
            d_inf.Message = sprintf('Progress: %d%% (%d / %d)', ...
                round(100 * step_counter / total_steps), ...
                step_counter, total_steps);
            drawnow limitrate;

            if d_inf.CancelRequested
                disp("Inference cancelled by user.");
                close(fig_inf);
                return;
            end
        end

        target_idx = idxs(i+1);
        start_i = max(1, i - numOfHistory);

        % local copy: ONLY for this target rollout (resets each estimation)
        tdoa_local = tdoa_corr;

        % ---- alpha filter state resets for each target estimation ----
        y_alpha_prev = nan;

        % rollout from (i-H) -> i to estimate target
        for j = start_i:i

            k_idx = idxs(j);
            l_idx = idxs(j+1);

            tdoa_k = tdoa_local(k_idx);
            tdoa_l = tdoa_local(l_idx);

            % --- IMU samples in [k_idx : l_idx] ---
            validRows = ~isnan(integrated_dateset(k_idx:l_idx, 2));
            data = integrated_dateset(k_idx:l_idx, 1:7);
            imu_epoch_samples = data(validRows, :);
            numValidRows = size(imu_epoch_samples,1);

            if numValidRows < 2
                imu_epoch_samples(2,:) = imu_epoch_samples(1,:);
                imu_epoch_samples(2,1) = imu_epoch_samples(2,1) + 0.1;
            end

            sample_tdoa_time = integrated_dateset(l_idx,1) - integrated_dateset(k_idx,1);
            interp_time_step_size = sample_tdoa_time / number_of_interp;

            for ii = 1:number_of_interp
                interp_time(ii) = integrated_dateset(k_idx,1) + interp_time_step_size * ii;
            end

            imu_epoch_samples_interp = interp1( ...
                imu_epoch_samples(:,1), imu_epoch_samples(:,2:7), ...
                interp_time, 'linear', 'extrap');

            dataset_epoch_data(1:number_of_interp, :) = imu_epoch_samples_interp;

            % anchors
            dataset_epoch_data(18, 1:3) = anchor_position(pid+1, :);
            if pid == 7
                dataset_epoch_data(18, 4:6) = anchor_position(1, :);
            else
                dataset_epoch_data(18, 4:6) = anchor_position(pid+2, :);
            end

            % two TDOA inputs
            dataset_epoch_data(19,1) = tdoa_k;
            dataset_epoch_data(19,2) = tdoa_l;

            % CNN input prep (110)
            X = dataset_epoch_data';
            X = X(:);
            X = X(1:110);
            y = predict_tdoa_correction(tdoaModel, X.');

            % ----------------------------------------------------------
            % Alpha filter ONLY within this rollout, reset per target_idx:
            % y_alpha(k) = (1-alpha)*y_alpha(k-1) + alpha*y(k)
            % First step: y_alpha = y
            % ----------------------------------------------------------
            if isnan(y_alpha_prev)
                y_alpha = y;
            else
                y_alpha = (1 - alpha) * y_alpha_prev + alpha * y;
            end
            y_alpha_prev = y_alpha;

            % feed filtered value forward inside this rollout
            tdoa_local(l_idx) = y_alpha;
        end

        % commit ONLY the final filtered target estimate
        tdoa_corr(target_idx) = y_alpha_prev;

        uwb_row = uwb_row_at_time(target_idx);
        if ~isnan(uwb_row)
            uwb_enhanced(uwb_row) = tdoa_corr(target_idx);
        end
    end
end

% fill missing outputs with raw
missing = isnan(uwb_enhanced);
uwb_enhanced(missing) = uwb(missing,3);

% close inference progress window (optional)
d_inf.Value = 1;
d_inf.Message = "Inference completed";
pause(1);
close(fig_inf);
close(d_inf);
%% calculate error
error_net = uwb_sim(:,3) - uwb_enhanced(1:max_num_of_epoch);
error_raw = uwb_sim(:,3) - uwb(:,3);

rms_raw = sqrt(mean((error_raw(:,1)).^2));
rms_net = sqrt(mean((error_net(:,1)).^2));

fprintf('The RMS error for uwb raw data is %.4f m\n', rms_raw);
fprintf('The RMS error for uwb net data is %.4f m\n', rms_net);

figure;
plot(error_raw); hold on;
plot(error_net);
legend('Raw error','Enhanced error');
grid on;

%% replace uwb with enhanced
uwb(:,3) = uwb_enhanced;

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
    if mod(k, max(1,round(K/100))) == 0
        d3.Value = k/K;
        d3.Message = sprintf('Progress: %d%% completed', round(100*k/K));
        drawnow limitrate;
    end

    [imu_k, imu_check] = isin(t_imu, t(k-1));
    [uwb_k, uwb_check] = isin(t_uwb, t(k-1));
    dt = t(k) - t(k-1);

    eskf.predict(imu(imu_k,:), dt, imu_check, k);

    if uwb_check
        eskf.UWB_correct(uwb(uwb_k,:), anchor_position, k);
    end
end

d_3.Value = 1;
d_3.Message = "Initialize completed";
pause(1);
close(fig3);
close(d3);
fprintf('Finish the state estimation\n');

%% Interpolate Vicon for ground truth
disp("Interpolate Vicon for ground truth...");

x_interp = interp1(t_vicon, pos_vicon(:,1), t, 'spline');
y_interp = interp1(t_vicon, pos_vicon(:,2), t, 'spline');
z_interp = interp1(t_vicon, pos_vicon(:,3), t, 'spline');
interp_gt = [x_interp(:), y_interp(:), z_interp(:)];

position_k = eskf.Xpo(:, 1:3);

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

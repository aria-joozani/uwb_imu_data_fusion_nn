%% ============================================================
%  FULL PIPELINE:
%  1) Load + integrate IMU & UWB
%  2) SINGLE-STEP CNN inference to enhance TDOA (NO HISTORY)
%  3) TDOA error metrics + per-pair plots
%  4) TDOA-ONLY trajectory estimation (NO ESKF)
%  5) Position metrics + plots
% ============================================================

%% 1) load data and network
clc; close all; clearvars;
projectRoot = setup_project();

csv_file = fullfile(projectRoot, 'csv-data', 'const4', 'const4-trial3-tdoa2-traj1.csv');
anchors  = fullfile(projectRoot, 'survey-results', 'anchor_const4_survey.txt');

data_extractor;
load(fullfile(projectRoot, 'models', 'active', 'trained_tdoa_net_cnn_2.mat'));

%% 2) extract and integrate imu & uwb data
disp("extract and integrate imu & uwb...");

t = unique([t_imu; t_uwb_sim]);
K = length(t);

% integrated_dateset columns:
% 1: time
% 2..7: imu (acc(3), gyro(3))
% 8..10: uwb (pair_id, ?, tdoa(m))
% 11: uwb_sim reference (m)
integrated_dateset = nan(K, 11);
integrated_dateset(:,1) = t;

% mapping from integrated timeline index -> uwb row index
uwb_row_at_time = nan(K,1);

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
        if d1.CancelRequested
            disp("Cancelled by user.");
            close(fig1);
            return;
        end
    end

    [imu_k, imu_check] = isin(t_imu, t(k-1));
    [uwb_k, uwb_check] = isin(t_uwb_sim, t(k-1));

    if imu_check
        integrated_dateset(k,2:7) = imu(imu_k,:);
    end

    if uwb_check
        integrated_dateset(k,8:10) = uwb(uwb_k,:);
        integrated_dateset(k,11)   = uwb_sim(uwb_k,3);
        uwb_row_at_time(k) = uwb_k;
    end
end

close(d1); close(fig1);

%% 3) SINGLE-STEP inference to enhance TDOA (NO HISTORY / NO CHAIN)
disp("single-step inference (no history) ...");

fig2 = uifigure('Name','single-step inference...','Position',[500 400 420 130]);
d2 = uiprogressdlg(fig2, ...
    'Title','Neural Network Inference (Single-step)', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

sreach_next_sample_window_size = 100;
number_of_interp = 17;

max_num_of_epoch = size(uwb,1);
uwb_enhanced = nan(max_num_of_epoch,1);

interp_time = zeros(number_of_interp,1);
dataset_epoch_data = zeros(number_of_interp+2, 6); % 19x6

m = 1;
for k = 2:K

    if mod(k, max(1,round(K/100))) == 0
        d2.Value = k/K;
        d2.Message = sprintf('Progress: %d%% completed', round(100*k/K));
        drawnow limitrate;
        if d2.CancelRequested
            disp("Cancelled by user.");
            close(fig2);
            return;
        end
    end

    if ~isnan(integrated_dateset(k,8))

        pair_id = integrated_dateset(k,8);

        % search next same pair sample
        if k + sreach_next_sample_window_size > K
            sreach_next_sample = K;
        else
            sreach_next_sample = k + sreach_next_sample_window_size;
        end

        l = nan;
        for ii = k+1:sreach_next_sample
            if integrated_dateset(ii,8) == pair_id
                l = ii;
                break;
            end
        end
        if isnan(l)
            continue;
        end

        % time interval
        sample_tdoa_time = integrated_dateset(l,1) - integrated_dateset(k,1);

        % IMU samples inside [k:l]
        validRows = ~isnan(integrated_dateset(k:l,2));
        data = integrated_dateset(k:l,1:7);   % time + imu
        imu_epoch_samples = data(validRows,:);

        if size(imu_epoch_samples,1) < 2
            imu_epoch_samples(2,:) = imu_epoch_samples(1,:);
            imu_epoch_samples(2,1) = imu_epoch_samples(2,1) + 0.1;
        end

        interp_time_step_size = sample_tdoa_time / number_of_interp;
        for jj = 1:number_of_interp
            interp_time(jj) = integrated_dateset(k,1) + interp_time_step_size * jj;
        end

        imu_epoch_samples_interp = interp1( ...
            imu_epoch_samples(:,1), imu_epoch_samples(:,2:7), ...
            interp_time, 'linear', 'extrap');

        % fill NN input tensor
        dataset_epoch_data(1:number_of_interp,:) = imu_epoch_samples_interp;

        % anchors (same logic as your code)
        dataset_epoch_data(18,1:3) = anchor_position(pair_id+1,:);
        if pair_id == 7
            dataset_epoch_data(18,4:6) = anchor_position(1,:);
        else
            dataset_epoch_data(18,4:6) = anchor_position(pair_id+2,:);
        end

        % two TDOA values from integrated dataset (single step)
        dataset_epoch_data(19,1) = integrated_dateset(k,10);
        dataset_epoch_data(19,2) = integrated_dateset(l,10);

        % prepare CNN input (110)
        X = dataset_epoch_data';
        X = X(:);
        X = X(1:110);
        X = (X - muX') ./ sigmaX';
        X4D = reshape(X, [110, 1, 1, size(X,2)]);

        % predict + denorm
        y = predict(net, X4D);
        y = y * sigmaY + muY;

        % write output aligned with uwb row
        uwb_enhanced(m) = y;
        m = m + 1;

        % jump to next pair sample
        k = l;
    end
end

% if any remain NaN, fill with raw uwb(:,3)
miss = isnan(uwb_enhanced);
uwb_enhanced(miss) = uwb(miss,3);

close(d2); close(fig2);

%% 4) TDOA error metrics + plots
disp("Compute TDOA error metrics...");

error_raw = uwb_sim(:,3) - uwb(:,3);
error_net = uwb_sim(:,3) - uwb_enhanced;

metrics_tdoa_raw = compute_metrics_1d(error_raw);
metrics_tdoa_net = compute_metrics_1d(error_net);

fprintf('\n=== TDOA metrics (meters) ===\n');
fprintf('RAW: RMSE=%.4f | MAE=%.4f | MedAE=%.4f | P95=%.4f | MAX=%.4f | Bias=%.4f\n', ...
    metrics_tdoa_raw.RMSE, metrics_tdoa_raw.MAE, metrics_tdoa_raw.MEDAE, ...
    metrics_tdoa_raw.P95, metrics_tdoa_raw.MAX, metrics_tdoa_raw.BIAS);

fprintf('NN : RMSE=%.4f | MAE=%.4f | MedAE=%.4f | P95=%.4f | MAX=%.4f | Bias=%.4f\n', ...
    metrics_tdoa_net.RMSE, metrics_tdoa_net.MAE, metrics_tdoa_net.MEDAE, ...
    metrics_tdoa_net.P95, metrics_tdoa_net.MAX, metrics_tdoa_net.BIAS);

figure('Name','TDOA error: Raw vs Enhanced');
plot(error_raw,'LineWidth',1); hold on;
plot(error_net,'LineWidth',1);
grid on; legend('Raw','Enhanced');
title('TDOA error (overall)'); xlabel('UWB epoch'); ylabel('Error (m)');

% ----- per-pair plots -----
disp("Plot per-pair TDOA errors...");
pair_ids = unique(uwb(:,1))';

for pid = pair_ids
    idx = (uwb(:,1) == pid);
    if sum(idx) < 5
        continue;
    end

    figure('Name',sprintf('Pair %d TDOA error', pid));
    plot(error_raw(idx),'LineWidth',1); hold on;
    plot(error_net(idx),'LineWidth',1);
    grid on; legend('Raw','Enhanced');
    title(sprintf('TDOA error for Pair %d', pid));
    xlabel('Measurement index (within this pair)'); ylabel('Error (m)');

    mr = compute_metrics_1d(error_raw(idx));
    mn = compute_metrics_1d(error_net(idx));
    fprintf('Pair %d -> RMSE raw=%.4f, nn=%.4f | P95 raw=%.4f, nn=%.4f\n', ...
        pid, mr.RMSE, mn.RMSE, mr.P95, mn.P95);
end

%% 5) TDOA-only trajectory estimation (NO ESKF)
disp("TDOA-only trajectory estimation (sliding window NLS) ...");

% --- settings ---
W = 12;                % window size (# last measurements)
use_3d = true;         % true: estimate x,y,z ; false: x,y with fixed z0
z0 = 0.07;             % used only if use_3d=false
max_iter = 80;

% measurement time vector aligned with uwb rows
t_uwb_use = t_uwb_sim;     % if you have a different t_uwb, replace this

M = size(uwb,1);
pos_tdoa_only = nan(M,3);
res_rms = nan(M,1);

p_prev = [1.25, 0.0, 0.07];

fig3 = uifigure('Name','TDOA-only trajectory','Position',[520 420 420 130]);
d3 = uiprogressdlg(fig3, ...
    'Title','TDOA-only position', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

for m = 1:M
    if mod(m, max(1,round(M/100))) == 0 || m == M
        d3.Value = m/M;
        d3.Message = sprintf('Progress: %d%% (%d / %d)', round(100*m/M), m, M);
        drawnow limitrate;
        if d3.CancelRequested
            disp("Cancelled by user.");
            close(fig3);
            break;
        end
    end

    i0 = max(1, m - W + 1);
    idx_win = i0:m;

    pid_win = uwb(idx_win,1);
    d_win   = uwb_enhanced(idx_win);    % use enhanced for trajectory

    if use_3d
        p_hat = solve_tdoa_nls_3d(p_prev, pid_win, d_win, anchor_position, max_iter);
        pos_tdoa_only(m,:) = p_hat(:).';
        p_prev = pos_tdoa_only(m,:);
        r = tdoa_residuals_3d(p_hat, pid_win, d_win, anchor_position);
    else
        p_xy = solve_tdoa_nls_2d(p_prev(1:2), z0, pid_win, d_win, anchor_position, max_iter);
        pos_tdoa_only(m,:) = [p_xy(:).', z0];
        p_prev = pos_tdoa_only(m,:);
        r = tdoa_residuals_3d([p_xy(:).', z0], pid_win, d_win, anchor_position);
    end

    res_rms(m) = sqrt(mean(r.^2));
end

close(d3); close(fig3);

%% 6) Compare TDOA-only trajectory with Vicon
disp("Compute position metrics (TDOA-only vs Vicon) ...");

x_gt = interp1(t_vicon, pos_vicon(:,1), t_uwb_use, 'spline');
y_gt = interp1(t_vicon, pos_vicon(:,2), t_uwb_use, 'spline');
z_gt = interp1(t_vicon, pos_vicon(:,3), t_uwb_use, 'spline');
gt_uwb = [x_gt(:), y_gt(:), z_gt(:)];

pos_err = pos_tdoa_only - gt_uwb;

metrics_pos = compute_metrics_xyz(pos_err);

fprintf('\n=== Position metrics (TDOA-only, meters) ===\n');
fprintf('RMSE_3D=%.4f | MAE_3D=%.4f | MedAE_3D=%.4f | P95_3D=%.4f | MAX_3D=%.4f\n', ...
    metrics_pos.RMSE_3D, metrics_pos.MAE_3D, metrics_pos.MEDAE_3D, metrics_pos.P95_3D, metrics_pos.MAX_3D);

fprintf('Axis RMSE: x=%.4f, y=%.4f, z=%.4f\n', metrics_pos.RMSE_X, metrics_pos.RMSE_Y, metrics_pos.RMSE_Z);
fprintf('Axis Bias: x=%.4f, y=%.4f, z=%.4f\n', metrics_pos.BIAS_X, metrics_pos.BIAS_Y, metrics_pos.BIAS_Z);

% plots
figure('Name','Trajectory: TDOA-only vs Vicon');
plot3(gt_uwb(:,1), gt_uwb(:,2), gt_uwb(:,3), 'LineWidth', 1); hold on;
plot3(pos_tdoa_only(:,1), pos_tdoa_only(:,2), pos_tdoa_only(:,3), 'LineWidth', 1);
grid on; legend('GT (Vicon)','TDOA-only');
title('Trajectory comparison'); xlabel('x (m)'); ylabel('y (m)'); zlabel('z (m)');

figure('Name','Position error norm (TDOA-only)');
plot(sqrt(sum(pos_err.^2,2)), 'LineWidth', 1);
grid on; title('Position error norm'); xlabel('UWB epoch'); ylabel('Error (m)');

figure('Name','TDOA fit residual RMS');
plot(res_rms, 'LineWidth', 1);
grid on; title('Residual RMS of TDOA fit (quality indicator)'); xlabel('UWB epoch'); ylabel('Residual RMS (m)');

%% ===================== Local Functions =====================

function S = compute_metrics_1d(e)
    e = e(:);
    S.RMSE  = sqrt(mean(e.^2));
    S.MAE   = mean(abs(e));
    S.MEDAE = median(abs(e));
    S.P95   = prctile(abs(e),95);
    S.MAX   = max(abs(e));
    S.BIAS  = mean(e);
    S.STD   = std(e);
end

function S = compute_metrics_xyz(err_xyz)
    e = err_xyz;
    en = sqrt(sum(e.^2,2));

    S.RMSE_3D  = sqrt(mean(en.^2));
    S.MAE_3D   = mean(abs(en));
    S.MEDAE_3D = median(abs(en));
    S.P95_3D   = prctile(en,95);
    S.MAX_3D   = max(en);

    S.RMSE_X = sqrt(mean(e(:,1).^2));
    S.RMSE_Y = sqrt(mean(e(:,2).^2));
    S.RMSE_Z = sqrt(mean(e(:,3).^2));

    S.BIAS_X = mean(e(:,1));
    S.BIAS_Y = mean(e(:,2));
    S.BIAS_Z = mean(e(:,3));
end

function r = tdoa_residuals_3d(p, pid_vec, d_vec, anchor_position)
    p = p(:).';
    N = numel(pid_vec);
    r = zeros(N,1);
    for k = 1:N
        pid = pid_vec(k);
        ai = anchor_position(pid+1, :);
        if pid == 7
            aj = anchor_position(1, :);
        else
            aj = anchor_position(pid+2, :);
        end
        pred = norm(p - ai) - norm(p - aj);
        r(k) = pred - d_vec(k);
    end
end

function p_hat = solve_tdoa_nls_3d(p0, pid_vec, d_vec, anchor_position, max_iter)
    fun = @(p) tdoa_residuals_3d(p, pid_vec, d_vec, anchor_position);

    if license('test','optimization_toolbox') && exist('lsqnonlin','file')
        opts = optimoptions('lsqnonlin','Display','off','MaxIterations',max_iter);
        p_hat = lsqnonlin(fun, p0, [], [], opts);
    else
        obj = @(p) sum(fun(p).^2);
        p_hat = fminsearch(obj, p0, optimset('Display','off','MaxIter',max_iter));
    end
end

function p_xy = solve_tdoa_nls_2d(p0_xy, z0, pid_vec, d_vec, anchor_position, max_iter)
    fun = @(p_xy) tdoa_residuals_3d([p_xy(:).', z0], pid_vec, d_vec, anchor_position);

    if license('test','optimization_toolbox') && exist('lsqnonlin','file')
        opts = optimoptions('lsqnonlin','Display','off','MaxIterations',max_iter);
        p_xy = lsqnonlin(fun, p0_xy, [], [], opts);
    else
        obj = @(p_xy) sum(fun(p_xy).^2);
        p_xy = fminsearch(obj, p0_xy, optimset('Display','off','MaxIter',max_iter));
    end
end

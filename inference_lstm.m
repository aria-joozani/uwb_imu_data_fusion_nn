%% load data and network
clc; close all; clear all;
csv_file = 'csv-data\const1\const1-trial1-tdoa2.csv';
anchors = 'survey-results\anchor_const1_survey.txt';
data_extractor;
load("networks\trained_tdoa_net_lstm.mat");
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
%% create epoch base data for each TDOA 
disp("create epoch base data for each TDOA...");

fig2 = uifigure('Name','create epoch base data for each TDOA...','Position',[500 400 400 120]);
d2 = uiprogressdlg(fig2, ...
    'Title','create epoch base data for each TDOA', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

sreach_next_sample_window_size = 100;
m = 1;
max_num_of_epoch = size(uwb);
max_num_of_epoch = max_num_of_epoch(1);
number_of_interp = 17;
sample_tdoa_time = zeros([max_num_of_epoch 1]);
sample_tdoa_space = zeros([max_num_of_epoch 1]);
interp_time = zeros([number_of_interp 1]);
imu_epoch_samples_count = zeros([max_num_of_epoch 6]);
dataset_epoch_data = zeros([number_of_interp+2 6 max_num_of_epoch]);
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
        if(size(l) ~= size(k))
            continue;
        end
        sample_tdoa_space(m) = l - k;
        sample_tdoa_time(m) =  integrated_dateset(l, 1) - integrated_dateset(k, 1);
        
        % Check for rows without any NaN
        validRows = ~isnan(integrated_dateset(k:l, 2));
        % Count them
        numValidRows = sum(validRows);
        imu_epoch_samples_count(m) = numValidRows;
        data = integrated_dateset(k:l, 1:7);
        imu_epoch_samples = data(validRows, :);
        interp_time_step_size = sample_tdoa_time(m)/17;

        for ii = 1:number_of_interp
            interp_time(ii) = integrated_dateset(k, 1) + interp_time_step_size * ii;
        end
        
        size_imu_epoch_samples = size(imu_epoch_samples);
        if(size_imu_epoch_samples(1) == 0)
            continue;
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
        dataset_epoch_data(1:17, :, m) = imu_epoch_samples_interp;
        dataset_epoch_data(18, 1:3, m) = ...
            anchor_position(pair_of_tag_check+1, :);
        if pair_of_tag_check == 7
            dataset_epoch_data(18, 4:6, m) = ... 
                anchor_position(1, :);
        else 
            dataset_epoch_data(18, 4:6, m) = ... 
                anchor_position(pair_of_tag_check+2, :);
        end

        dataset_epoch_data(19, 1, m) = integrated_dateset(k, 10);
        dataset_epoch_data(19, 2, m) = integrated_dateset(l, 10);
        % dataset_epoch_data(19, 3, m) = integrated_dateset(l, 11);
        m = m + 1;
        k = l;
    end
end

%%
X = reshape(permute(dataset_epoch_data, [3 2 1]), max_num_of_epoch, 19*6);
X = X(:,1:110);

% Reshape X into sequences: [features × timeSteps × observations]
% Assuming each row is a time step and you want to create sequences of fixed length
sequenceLength = 20;  % You can adjust this
numSamples = floor(size(X,1) / sequenceLength);

X = reshape(X(1:numSamples*sequenceLength, :)', size(X,2), sequenceLength, []);
N = size(X, 3);
Xsimulation = squeeze(num2cell(X(:, :, 1:N), [1 2]))';

Ysimulation = predict(net, Xsimulation);
%% calculate error 
error_net = uwb_sim(:,3) - uwb_enhanced(1:max_num_of_epoch);
error_raw = uwb_sim(:,3) - uwb(:,3);

rms_raw = sqrt(mean((error_raw(:,1)).^2));
rms_net = sqrt(mean((error_net(:,1)).^2));

fprintf('The RMS error for uwb raw data is %.4f m\n', rms_raw);
fprintf('The RMS error for uwb net data is %.4f m\n', rms_net);

hold
plot(error_raw)
plot(error_net)

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
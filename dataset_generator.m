disp("load dataset...");
data_extractor;
%% generate dataset
disp("generate dataset...");


%% Initialize ESKF with UWB data 
disp("Write imu and uwb in integrated table...");

fig1 = uifigure('Name','extract and intgrate imu & uwb...','Position',[500 400 400 120]);
d1 = uiprogressdlg(fig1, ...
    'Title','extract and intgrate imu & uwb', ...
    'Message','Initializing...', ...
    'Cancelable','on', ...
    'Value',0);

t = unique([t_imu; t_uwb_sim]);
K = length(t);

% t 1 + acc 3 + gyro 3 + UWB 3 + UWB_sim 1
dataset_export = nan(K, 11);

dataset_export(:, 1) = t;

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
        dataset_export(k , 2:7) = imu(imu_k,:);
        %%eskf.predict(imu(imu_k,:), dt, imu_check, k);
    end

    if uwb_check
        dataset_export(k , 8:10) = uwb(uwb_k,:);
        dataset_export(k , 11) = uwb_sim(uwb_k,3);
        %%eskf.UWB_correct(uwb_sim(uwb_k,:), anchor_position, k);
    end
end
close(d1);
close(fig1);
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
    if ~isnan(dataset_export(k, 8))
        pair_of_tag_check = dataset_export(k, 8);
        
        if k+sreach_next_sample_window_size > K
            sreach_next_sample = K;
        else 
            sreach_next_sample = k + sreach_next_sample_window_size;
        end
        for l = k+1:sreach_next_sample
            if dataset_export(l, 8) == pair_of_tag_check
                break;
            end
        end
        if(size(l) ~= size(k))
            continue;
        end
        sample_tdoa_space(m) = l - k;
        sample_tdoa_time(m) =  dataset_export(l, 1) - dataset_export(k, 1);
        
        % Check for rows without any NaN
        validRows = ~isnan(dataset_export(k:l, 2));
        % Count them
        numValidRows = sum(validRows);
        imu_epoch_samples_count(m) = numValidRows;
        data = dataset_export(k:l, 1:7);
        imu_epoch_samples = data(validRows, :);
        interp_time_step_size = sample_tdoa_time(m)/17;

        for ii = 1:number_of_interp
            interp_time(ii) = dataset_export(k, 1) + interp_time_step_size * ii;
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

        dataset_epoch_data(19, 1, m) = dataset_export(k, 10);
        dataset_epoch_data(19, 2, m) = dataset_export(l, 10);
        dataset_epoch_data(19, 3, m) = dataset_export(l, 11);
        m = m + 1;
        k = l;
    end
end

close(d2);
close(fig2);

%figure;
%plot(sample_tdoa_time);
%figure;
%plot(sample_tdoa_spacing);
%figure;
%plot(imu_epoch_samples_count);
%%
dataset_export_ready_to_merge = reshape(permute(dataset_epoch_data, [3 2 1]), max_num_of_epoch, 19*6);
dataset_export_ready_to_merge = dataset_export_ready_to_merge(:,1:111);

%% 
T = array2table(dataset_export_ready_to_merge, 'VariableNames', ...
   {'acc_x_1', 'acc_y_1', 'acc_z_1', 'gyro_x_1', 'gyro_y_1', 'gyro_z_1', ...
    'acc_x_2', 'acc_y_2', 'acc_z_2', 'gyro_x_2', 'gyro_y_2', 'gyro_z_2', ...
    'acc_x_3', 'acc_y_3', 'acc_z_3', 'gyro_x_3', 'gyro_y_3', 'gyro_z_3', ...
    'acc_x_4', 'acc_y_4', 'acc_z_4', 'gyro_x_4', 'gyro_y_4', 'gyro_z_4', ...
    'acc_x_5', 'acc_y_5', 'acc_z_5', 'gyro_x_5', 'gyro_y_5', 'gyro_z_5', ...
    'acc_x_6', 'acc_y_6', 'acc_z_6', 'gyro_x_6', 'gyro_y_6', 'gyro_z_6', ...
    'acc_x_7', 'acc_y_7', 'acc_z_7', 'gyro_x_7', 'gyro_y_7', 'gyro_z_7', ...
    'acc_x_8', 'acc_y_8', 'acc_z_8', 'gyro_x_8', 'gyro_y_8', 'gyro_z_8', ...
    'acc_x_9', 'acc_y_9', 'acc_z_9', 'gyro_x_9', 'gyro_y_9', 'gyro_z_9', ...
    'acc_x_10', 'acc_y_10', 'acc_z_10', 'gyro_x_10', 'gyro_y_10', 'gyro_z_10', ...
    'acc_x_11', 'acc_y_11', 'acc_z_11', 'gyro_x_11', 'gyro_y_11', 'gyro_z_11', ...
    'acc_x_12', 'acc_y_12', 'acc_z_12', 'gyro_x_12', 'gyro_y_12', 'gyro_z_12', ...
    'acc_x_13', 'acc_y_13', 'acc_z_13', 'gyro_x_13', 'gyro_y_13', 'gyro_z_13', ...
    'acc_x_14', 'acc_y_14', 'acc_z_14', 'gyro_x_14', 'gyro_y_14', 'gyro_z_14', ...
    'acc_x_15', 'acc_y_15', 'acc_z_15', 'gyro_x_15', 'gyro_y_15', 'gyro_z_15', ...
    'acc_x_16', 'acc_y_16', 'acc_z_16', 'gyro_x_16', 'gyro_y_16', 'gyro_z_16', ...
    'acc_x_17', 'acc_y_17', 'acc_z_17', 'gyro_x_17', 'gyro_y_17', 'gyro_z_17', ...
    'anch_a_x', 'anch_a_y', 'anch_a_z', 'anch_b_x', 'anch_b_y', 'anch_b_z', ...
    'uwb_tdoA_last_gt', 'uwb_tdoA_now', 'uwb_tdoA_now_gt'});
writetable(T, export_csv_file);

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

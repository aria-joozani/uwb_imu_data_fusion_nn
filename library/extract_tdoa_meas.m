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
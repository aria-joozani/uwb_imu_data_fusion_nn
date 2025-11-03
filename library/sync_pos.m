function pos_s = sync_pos(t_1, pos_1, t_2)
    x_s = interp_meas(t_1, pos_1(:,1), t_2);
    y_s = interp_meas(t_1, pos_1(:,2), t_2);
    z_s = interp_meas(t_1, pos_1(:,3), t_2);
    pos_s = [x_s(:), y_s(:), z_s(:)];
end
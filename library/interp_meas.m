function syn_m1 = interp_meas(t1, meas1, t2)
    % synchronized meas1 w.r.t. t2
    t1 = squeeze(t1);
    t2 = squeeze(t2);
    meas1 = squeeze(meas1);
    syn_m1 = interp1(t1, meas1, t2, 'linear', 'extrap');
end
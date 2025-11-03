function tof = extract_tof(df)
    t_tof = deleteNAN(df.t_tof(:));
    tof_meas = deleteNAN(df.tof(:));
    tof = [t_tof, tof_meas];
end
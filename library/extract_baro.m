function baro = extract_baro(df)
    t_baro = deleteNAN(df.t_baro(:));
    baro_meas = deleteNAN(df.baro(:));
    baro = [t_baro, baro_meas];
end
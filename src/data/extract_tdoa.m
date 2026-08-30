function tdoa = extract_tdoa(df)
    t_tdoa = deleteNAN(df.t_tdoa(:));
    idA = deleteNAN(df.idA(:));
    idB = deleteNAN(df.idB(:));
    tdoa_meas = deleteNAN(df.tdoa_meas(:));
    tdoa = [t_tdoa, idA, idB, tdoa_meas];
end
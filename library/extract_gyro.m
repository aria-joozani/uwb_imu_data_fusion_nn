function gyro = extract_gyro(df)
    t_gyro = deleteNAN(df.t_gyro(:));
    gyro_x = deleteNAN(df.gyro_x(:));
    gyro_y = deleteNAN(df.gyro_y(:));
    gyro_z = deleteNAN(df.gyro_z(:));
    gyro = [t_gyro, gyro_x, gyro_y, gyro_z];
end
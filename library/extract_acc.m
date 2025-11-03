function acc = extract_acc(df)
    t_acc = deleteNAN(df.t_acc(:));
    acc_x = deleteNAN(df.acc_x(:));
    acc_y = deleteNAN(df.acc_y(:));
    acc_z = deleteNAN(df.acc_z(:));
    acc = [t_acc, acc_x, acc_y, acc_z];
end

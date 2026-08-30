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
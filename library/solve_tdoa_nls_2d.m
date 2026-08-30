function p_xy = solve_tdoa_nls_2d(p0_xy, z0, pid_vec, d_vec, anchor_position, max_iter)
% Solve 2D NLS with fixed z = z0

    fun = @(p_xy) tdoa_residuals_3d([p_xy(:).', z0], pid_vec, d_vec, anchor_position);

    if license('test','optimization_toolbox') && exist('lsqnonlin','file')
        opts = optimoptions('lsqnonlin', ...
            'Display','off', ...
            'MaxIterations',max_iter);
        p_xy = lsqnonlin(fun, p0_xy, [], [], opts);
    else
        obj = @(p_xy) sum(fun(p_xy).^2);
        p_xy = fminsearch(obj, p0_xy, optimset('Display','off','MaxIter',max_iter));
    end
end
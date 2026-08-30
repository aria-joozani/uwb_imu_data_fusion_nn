function p_hat = solve_tdoa_nls_3d(p0, pid_vec, d_vec, anchor_position, max_iter)
% Solve 3D NLS: minimize sum(r^2)

    fun = @(p) tdoa_residuals_3d(p, pid_vec, d_vec, anchor_position);

    if license('test','optimization_toolbox') && exist('lsqnonlin','file')
        opts = optimoptions('lsqnonlin', ...
            'Display','off', ...
            'MaxIterations',max_iter);
        p_hat = lsqnonlin(fun, p0, [], [], opts);
    else
        obj = @(p) sum(fun(p).^2);
        p_hat = fminsearch(obj, p0, optimset('Display','off','MaxIter',max_iter));
    end
end
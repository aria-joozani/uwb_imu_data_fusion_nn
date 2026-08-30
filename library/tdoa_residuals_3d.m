function r = tdoa_residuals_3d(p, pid_vec, d_vec, anchor_position)
% Residual for each TDOA measurement:
% r = (||p-ai|| - ||p-aj||) - d_ij

    p = p(:).';
    N = numel(pid_vec);
    r = zeros(N,1);

    for k = 1:N
        pid = pid_vec(k);

        ai = anchor_position(pid+1, :);
        if pid == 7
            aj = anchor_position(1, :);
        else
            aj = anchor_position(pid+2, :);
        end

        pred = norm(p - ai) - norm(p - aj);
        r(k) = pred - d_vec(k);
    end
end
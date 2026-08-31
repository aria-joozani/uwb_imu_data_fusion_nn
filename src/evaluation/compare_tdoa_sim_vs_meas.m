function [rmse, mean_err, error_vector] = compare_tdoa_sim_vs_meas(tdoa_sim, tdoa_meas)
%COMPARE_TDOA_SIM_VS_MEAS Compare simulated TDOA with measured TDOA values.
%
% Inputs:
%   tdoa_sim  - Nx4 array: [time, idA, idB, simulated_tdoa]
%   tdoa_meas - Nx4 array: [time, idA, idB, measured_tdoa]
%
% Outputs:
%   rmse         - Root Mean Squared Error
%   mean_err     - Mean absolute error
%   error_vector - Nx1 array of signed error per row

    assert(size(tdoa_sim,1) == size(tdoa_meas,1), 'TDOA arrays must have the same length.');

    error_vector = zeros(size(tdoa_sim,1),1);
    match_count = 0;

    for i = 1:size(tdoa_sim, 1)
        % Match based on time, idA, idB
        if tdoa_sim(i,1) == tdoa_meas(i,1) && ...
           tdoa_sim(i,2) == tdoa_meas(i,2) && ...
           tdoa_sim(i,3) == tdoa_meas(i,3)

            error_vector(i) = tdoa_meas(i,4) - tdoa_sim(i,4);
            match_count = match_count + 1;
        else
            warning("Row %d: mismatch in [time, idA, idB] between simulated and measured data.", i);
        end
    end

    % Preserve the existing measured-minus-simulated error vector while
    % centralizing its sign-insensitive RMSE and MAE calculation.
    metrics = calculate_tdoa_metrics(error_vector, zeros(size(error_vector)));
    rmse = metrics.RMSE;
    mean_err = metrics.MAE;

    fprintf("✅ TDOA comparison complete on %d matched entries\n", match_count);
    fprintf("🔹 RMSE:       %.3e mm\n", rmse*10e3);
    fprintf("🔹 Mean Error: %.3e mm\n", mean_err*10e3);
end

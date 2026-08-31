function metrics = calculate_position_metrics(referencePosition, estimatedPosition)
%CALCULATE_POSITION_METRICS Calculate axis and Euclidean position metrics.
%
% metrics = calculate_position_metrics(referencePosition, estimatedPosition)
%
% Inputs:
%   referencePosition   N x 3 reference xyz position [m].
%   estimatedPosition   N x 3 estimated xyz position [m].
%
% Error convention:
%   error_xyz = estimatedPosition - referencePosition
%
% Definitions:
%   RMSE_3D = sqrt(mean(dx^2 + dy^2 + dz^2))
%   MAE_3D  = mean(sqrt(dx^2 + dy^2 + dz^2))
%
% LEGACY_MA_XXY preserves the historical x+y+x aggregate for regression
% reporting only. It is not a valid 3-D MAE and must not be used as one.

    validateattributes(referencePosition, {'numeric'}, ...
        {'2d', 'real', 'nonempty', 'ncols', 3}, mfilename, 'referencePosition');
    validateattributes(estimatedPosition, {'numeric'}, ...
        {'2d', 'real', 'nonempty', 'ncols', 3}, mfilename, 'estimatedPosition');
    if ~isequal(size(referencePosition), size(estimatedPosition))
        error('metrics:SizeMismatch', ...
            'Reference and estimated positions must have identical N-by-3 size.');
    end

    errorXyz = double(estimatedPosition) - double(referencePosition);
    errorNorm = sqrt(sum(errorXyz .^ 2, 2));
    axisRmse = sqrt(mean(errorXyz .^ 2, 1));
    axisMae = mean(abs(errorXyz), 1);
    axisBias = mean(errorXyz, 1);
    axisStd = std(errorXyz, 0, 1);

    metrics = struct();
    metrics.RMSE_X = axisRmse(1);
    metrics.RMSE_Y = axisRmse(2);
    metrics.RMSE_Z = axisRmse(3);
    metrics.RMS_ALL = sqrt(sum(axisRmse .^ 2));
    metrics.RMSE_3D = sqrt(mean(errorNorm .^ 2));
    metrics.MAE_X = axisMae(1);
    metrics.MAE_Y = axisMae(2);
    metrics.MAE_Z = axisMae(3);
    metrics.MAE_3D = mean(errorNorm);
    metrics.MEDAE_3D = median(errorNorm);
    metrics.P95_3D = prctile(errorNorm, 95);
    metrics.MAX_3D = max(errorNorm);
    metrics.BIAS_X = axisBias(1);
    metrics.BIAS_Y = axisBias(2);
    metrics.BIAS_Z = axisBias(3);
    metrics.STD_X = axisStd(1);
    metrics.STD_Y = axisStd(2);
    metrics.STD_Z = axisStd(3);
    metrics.LEGACY_MA_XXY = axisMae(1) + axisMae(2) + axisMae(1);
    metrics.COUNT = size(errorXyz, 1);
    metrics.ERROR_XYZ = errorXyz;
    metrics.ERROR_NORM = errorNorm;
    metrics.ERROR_CONVENTION = 'estimate_minus_reference';
    metrics.UNITS = 'm';
end

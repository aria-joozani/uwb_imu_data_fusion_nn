function metrics = calculate_tdoa_metrics(reference, estimate)
%CALCULATE_TDOA_METRICS Calculate scalar TDoA error metrics.
%
% metrics = calculate_tdoa_metrics(reference, estimate)
%
% Inputs:
%   reference  N-element ideal/reference TDoA range difference [m].
%   estimate   N-element measured or predicted TDoA range difference [m].
%
% Error convention:
%   error = reference - estimate
%
% Output fields include RMSE, MAE, MEDAE, P95, MAX, BIAS, STD, COUNT, and
% ERROR. All error statistics except COUNT are in metres. This convention
% preserves the sign used by the reviewed TDoA evaluation scripts.

    validateattributes(reference, {'numeric'}, {'vector', 'real', 'nonempty'}, ...
        mfilename, 'reference');
    validateattributes(estimate, {'numeric'}, {'vector', 'real', 'nonempty'}, ...
        mfilename, 'estimate');
    reference = double(reference(:));
    estimate = double(estimate(:));
    if numel(reference) ~= numel(estimate)
        error('metrics:SizeMismatch', ...
            'Reference and estimate must contain the same number of values.');
    end

    errorVector = reference - estimate;
    absoluteError = abs(errorVector);

    metrics = struct();
    metrics.RMSE = sqrt(mean(errorVector .^ 2));
    metrics.MAE = mean(absoluteError);
    metrics.MEDAE = median(absoluteError);
    metrics.P95 = prctile(absoluteError, 95);
    metrics.MAX = max(absoluteError);
    metrics.BIAS = mean(errorVector);
    metrics.STD = std(errorVector, 0);
    metrics.COUNT = numel(errorVector);
    metrics.ERROR = errorVector;
    metrics.ERROR_CONVENTION = 'reference_minus_estimate';
    metrics.UNITS = 'm';
end

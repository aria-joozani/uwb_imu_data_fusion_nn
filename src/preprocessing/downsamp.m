function data_ds = downsamp(data)
    % Down-sample UWB data three times by a factor of 2
    data_ds = data;
    data_ds = data(1:2:end, :);         % First downsample
    data_ds = data_ds(1:2:end, :);      % Second downsample
    data_ds = data_ds(1:2:end, :);      % Third downsample
end
function [index, found] = isin(t_np, t_k)
    idx = find(t_np == t_k, 1);
    if ~isempty(idx)
        index = idx;
        found = true;
    else
        index = 1;
        found = false;
    end
end

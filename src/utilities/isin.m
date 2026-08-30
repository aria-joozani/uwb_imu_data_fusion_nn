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
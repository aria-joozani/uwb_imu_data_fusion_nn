function config = load_experiment_config(name, overrides)
%LOAD_EXPERIMENT_CONFIG Load a named experiment configuration.
%
% config = load_experiment_config("baseline")
% config = load_experiment_config("baseline", overrides)
%
% Overrides are merged recursively. A nested struct therefore permits a
% caller to change one setting without copying the complete configuration.

    if nargin < 1 || isempty(name)
        name = "baseline";
    end
    if nargin < 2
        overrides = struct();
    end

    validateattributes(name, {'char', 'string'}, {'scalartext'}, ...
        mfilename, 'name');
    validateattributes(overrides, {'struct'}, {'scalar'}, ...
        mfilename, 'overrides');

    switch lower(string(name))
        case {"baseline", "baseline_legacy"}
            config = baseline_config();
        case {"legacy_pipeline", "legacy_preprocessing"}
            config = legacy_pipeline_config();
        otherwise
            error('config:UnknownExperiment', ...
                'Unknown experiment configuration "%s".', string(name));
    end

    config = mergeStruct(config, overrides);
end

function output = mergeStruct(base, overrides)
    output = base;
    names = fieldnames(overrides);
    for i = 1:numel(names)
        name = names{i};
        if isfield(output, name) && isstruct(output.(name)) && ...
                isscalar(output.(name)) && isstruct(overrides.(name)) && ...
                isscalar(overrides.(name))
            output.(name) = mergeStruct(output.(name), overrides.(name));
        else
            output.(name) = overrides.(name);
        end
    end
end

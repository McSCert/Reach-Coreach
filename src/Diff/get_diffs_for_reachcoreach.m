function [oldBlocks, oldLines, newBlocks, newLines] = get_diffs_for_reachcoreach(model1, model2, diffTree)
    %
    % Inputs:
    %   model1
    %   model2
    %   diffTree    [Optional] Result of:
    %                   slxmlcomp.compare(oldModel,newModel)
    %               Only used to speed up results.
    
    % Note: The implementation here does not look for changes within stateflow.
    
    % Compare models.
    diffStruct = model_diff(model1, model2, diffTree);
    
    % The changes that we need for Reach/Coreach are blocks, lines, and
    % lines connected to changed ports.
    oldBlocks = unique([diffStruct.blocks.del.old, diffStruct.blocks.mod0.old]);
    if isempty(oldBlocks)
        oldBlocks = {};
    end
    
    newBlocks = unique([diffStruct.blocks.mod0.new, diffStruct.blocks.add.new]);
    if isempty(newBlocks)
        newBlocks = {};
    end
    
    oldLines = unique([diffStruct.lines.del.old, diffStruct.lines.mod0.old, ...
        get_port_lines(diffStruct.ports.del.old), ...
        get_port_lines(diffStruct.ports.mod0.old)]);
    
    newLines = unique([diffStruct.lines.add.new, diffStruct.lines.mod0.new, ...
        get_port_lines(diffStruct.ports.add.new), ...
        get_port_lines(diffStruct.ports.mod0.new)]);
end

function lines = get_port_lines(ports)
    % Get lines connected to given ports.
    lines = arrayfun(@(ph) get_param(ph, 'Line'), ports);
    lines = lines(arrayfun(@(lh) lh ~= -1, lines));
end
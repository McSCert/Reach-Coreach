function [oldBlocks, oldLines, newBlocks, newLines, oldSubs, newSubs] = highlight_model_diffs(model1, model2, diffTree) %oldBlocks, oldLines, newBlocks, newLines)
    %
    
    if nargin < 3
        [oldBlocks, oldLines, newBlocks, newLines] = get_diffs_for_reachcoreach(model1, model2);
    end
    
    highlight_blocks(oldBlocks);
    highlight_blocks(newBlocks);
    
    oldSubs = unique([get_subs_among_blocks(oldBlocks), get_subs_among_lines(oldLines)]);
    newSubs = unique([get_subs_among_blocks(newBlocks), get_subs_among_lines(newLines)]);
    
    highlight_blocks(oldSubs);
    highlight_blocks(newSubs);
    
end

function subs = get_subs_among_blocks(blocks)
    subs = {};
    for i = 1:length(blocks)
        parent = get_param(blocks{i}, 'Parent');
        if ~any(strcmp(parent, subs))
            subs{end+1} = parent;
        end
    end
end

function subs = get_subs_among_lines(lines)
    subs = {};
    for i = 1:length(lines)
        parent = get_param(lines(i), 'Parent');
        parent = getfullname(parent);
        if ~any(strcmp(parent, subs))
            subs{end+1} = parent;
        end
    end
end

function [oldBlocks, oldLines, newBlocks, newLines] = get_diffs_for_reachcoreach(model1, model2)
    
    % Note: The implementation here does not look for changes within stateflow.
    
    % Compare models.
    diffStruct = model_diff(model1, model2);
    
    % The changes that we need for Reach/Coreach are blocks, lines, and
    % lines connected to changed ports.
    oldBlocks = unique([diffStruct.blocks.del.old, diffStruct.blocks.mod0.old]);
    
    newBlocks = unique([diffStruct.blocks.mod0.new, diffStruct.blocks.add.new]);
    
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
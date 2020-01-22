function [oldReachedObjects, newReachedObjects] = Reach_Diff(oldModel, newModel, direction)
    % REACH_DIFF Identifies blocks and lines in oldModel and newModel that are 
    % potentially impacted by the changes made between the models.
    % 
    % Inputs:
    %   oldModel    The original version of a model.
    %   newModel    The new version of a model.
    %   direction   Indicates direction of analysis. Default: 0 for downstream
    %               analysis (Reach), 1 for upstream analysis (Coreach).
    %
    % Outputs:
    %   oldReachedObjects   Handles of blocks and lines in oldModel that are
    %                       potentially impacted.
    %   newReachedObjects   Handles of blocks and lines in newModel that are
    %                       potentially impacted.
    % 
    
    if nargin < 3
        direction = 0; % Downstream trace (Reach).
    end
    
    % Load models.
    if ~bdIsLoaded(oldModel)
            open_system(oldModel)
            closeOld = true;
    else
        closeOld = false;
    end
    if ~bdIsLoaded(newModel)
            open_system(newModel)
            closeNew = true;
    else
        closeNew = false;
    end
    
    % Get differences.
    [oldBlocks, oldLines, newBlocks, newLines] = get_diffs_for_reachcoreach(oldModel, newModel);
    
    % Get the reaches.
    oldReachedObjects = getReach(oldModel, oldBlocks, oldLines, direction);
    newReachedObjects = getReach(newModel, newBlocks, newLines, direction);
    
    % Close models.
    if closeOld
        close_system(oldModel, 0)
    end
    if closeNew
        close_system(newModel, 0)
    end
end

function reachedObjs = getReach(model, blocks, lines, direction)
    reachObj = ReachCoreach(model);
    reachObj.setHiliteFlag(false);
    
    if direction == 0
        % Reach.
        reachObj.reachAll(blocks, lines);
        reachedObjs = reachObj.ReachedObjects;
    elseif direction == 1
        % Coreach.
        reachObj.coreachAll(blocks, lines);
        reachedObjs = reachObj.CoreachedObjects;
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
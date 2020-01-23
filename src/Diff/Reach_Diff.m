function [oldReachedObjects, newReachedObjects, diffTree] = Reach_Diff(oldModel, newModel, direction, diffTree)
    % REACH_DIFF Identifies blocks and lines in oldModel and newModel that are 
    % potentially impacted by the changes made between the models.
    % 
    % Inputs:
    %   oldModel    The original version of a model.
    %   newModel    The new version of a model.
    %   direction   Indicates direction of analysis. Default: 0 for downstream
    %               analysis (Reach), 1 for upstream analysis (Coreach).
    %   diffTree    [Optional] Result of:
    %                   slxmlcomp.compare(oldModel,newModel)
    %               Only used to speed up results.
    %
    % Outputs:
    %   oldReachedObjects   Handles of blocks and lines in oldModel that are
    %                       potentially impacted.
    %   newReachedObjects   Handles of blocks and lines in newModel that are
    %                       potentially impacted.
    %   diffTree            Tree generated from:
    %                           slxmlcomp.compare(oldModel,newModel)
    %                       Can be passed back in on future calls using the same
    %                       models to speed up results.
    % 
    
    if nargin < 3
        direction = 0; % Downstream trace (Reach).
    end
    
    % Get comparison tree.
    if nargin < 4
        diffTree = slxmlcomp.compare(oldModel, newModel);
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
    [oldBlocks, oldLines, newBlocks, newLines] = get_diffs_for_reachcoreach(oldModel, newModel, diffTree);
    
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
function [oldReachedObjects, newReachedObjects, diffTree] = Reach_Diff(oldModel, newModel, highlight, direction, diffTree)
    % REACH_DIFF Identifies blocks and lines in oldModel and newModel that are 
    % potentially impacted by the changes made between the models.
    % 
    % Inputs:
    %   oldModel    The original version of a model.
    %   newModel    The new version of a model.
    %   highlight   [Optional] Indicates whether or not to highlight the
    %               differences and impacts. Default: 1 to highlight differences
    %               with DarkGreen foreground and Red background and highlight
    %               impacts of those differences with Yellow foreground and Red
    %               background; use 0 for no highlighting.
    %   direction   [Optional] Indicates direction of analysis. Default: 0 for
    %               downstream analysis (Reach), 1 for upstream analysis
    %               (Coreach).
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
    
    % Input handling.
    if nargin < 3
        highlight = 1;
    end
    if nargin < 4
        direction = 0; % Downstream trace (Reach).
    end
    if nargin < 5
        % Get comparison tree.
        diffTree = slxmlcomp.compare(oldModel, newModel);
    end
    
    impactBackground = 'Yellow';
    impactForeground = 'Red';
    diffBackground = 'DarkGreen';
    diffForeground = 'Red';
    
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
    
    %
    if highlight
       % Do highlighting.
       
       % Highlight impacts.
       oldObjsStruct = groupObjectsByType(oldReachedObjects);
       if any(strcmp('block', fields(oldObjsStruct)))
           highlight_blocks(oldObjsStruct.block, impactBackground, impactForeground);
       end
       
       newObjsStruct = groupObjectsByType(newReachedObjects);
       if any(strcmp('block', fields(newObjsStruct)))
           highlight_blocks(newObjsStruct.block, impactBackground, impactForeground);
       end
       
       % Highlight differences (includes subsystems that contain differences,
       % but that may not different otherwise).
       highlight_blocks_with_subs(oldBlocks, oldLines, diffBackground, diffForeground);
       highlight_blocks_with_subs(newBlocks, newLines, diffBackground, diffForeground);
    end
    
    % Close models.
    if ~highlight
        if closeOld
            close_system(oldModel, 0)
        end % else do not close model because it was already opened.
        if closeNew
            close_system(newModel, 0)
        end % else do not close model because it was already opened.
    end % else do not close models because they were highlighted.
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

function simObjs = groupObjectsByType(objects)
    %
    %
    %   Inputs:
    %       objects     Array of Simulink object handles.
    %
    %   Outputs:
    %       simObjs     Struct with a separate field for each Type of object in
    %                   objects. Each field contains an array of the object
    %                   handles in object of that type.
    %
    
    % Create function for finding the type.
    % TODO: Make a function that takes this function handle as input so that it
    % can be more versatile (would need to make some changes to handle typing
    % issues).
    getCategory = @(o) get_param(o, 'Type');
    
    simObjs = struct;
    for i = 1:length(objects)
        obj = objects(i);
        cat = getCategory(obj);
        
        if any(strcmp(cat, fields(simObjs)))
            % Add current object to its corresponding field.
            simObjs.(cat)(end+1) = obj;
        else
            % Create new field with current object in it only.
            simObjs.(cat) = obj;
        end
    end
end

function highlight_blocks_with_subs(blocks, lines, background, foreground)

    if nargin < 3
        background = 'Yellow';
    end
    if nargin < 4
        foreground = 'Red';
    end
    
    highlight_blocks(blocks, background, foreground);
    newSubs = unique([get_subs_among_blocks(blocks), get_subs_among_lines(lines)]);
    highlight_blocks(newSubs, background, foreground);
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
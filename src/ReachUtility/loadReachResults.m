function reachObj = loadReachResults(filename, highlight)
    % LOADREACHRESULTS Load a reach/coreach object for continued use. Updates
    % handles of reached / coreached objects in the model. Note this was only
    % developed for highlighting the reached/coreached blocks again, there may
    % be unexpected behaviour if doing more than that.
    %
    % Inputs:
    %   filename    Name of the file where the reach/coreach object is saved.
    %   highlight   Logical true to automatically highlight previously
    %               reached/coreached blocks, false to just load the
    %               reach/coreach object.
    %
    % Outputs:
    %   reachObj    Updated reach/coreach object.
    
    %
    S = load(filename, '-mat', 'reachObj', 'reachedObjectNames', 'coreachedObjectNames');
    reachObj = S.reachObj;
    reachedObjectNames = S.reachedObjectNames;
    coreachedObjectNames = S.coreachedObjectNames;
    
    % Open system to identify new handles.
    if ~bdIsLoaded(reachObj.RootSystemName)
        open_system(reachObj.RootSystemName)
    end
    
    %
    reachObj.ReachedObjects = []; % Erase old handles.
    for i = 1:length(reachedObjectNames)
        blockName = reachedObjectNames{i};
        blockHandle = get_param(blockName, 'Handle');
        reachObj.ReachedObjects(end+1) = blockHandle;
    end
    
    %
    reachObj.CoreachedObjects = []; % Erase old handles.
    for i = 1:length(coreachedObjectNames)
        blockName = coreachedObjectNames{i};
        blockHandle = get_param(blockName, 'Handle');
        reachObj.CoreachedObjects(end+1) = blockHandle;
    end
    
    %
    if highlight
        reachObj.hiliteObjects;
    end
end
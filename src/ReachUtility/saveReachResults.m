function filename = saveReachResults(reachObj, filename)
    % SAVEREACHRESULTS Save a reach/coreach object for future use. Note this
    % does not currently save the reached signal lines.
    % 
    % Inputs:
    %   reachObject     Object created from reach/coreach analyses or leave
    %                   empty to identify the reach object used for the
    %                   currently open model automatically.
    %   filename        [Optional] Name to use to save the results. If path is
    %                   not specified, then it is saved in the current
    %                   directory. If filename is not specified, then the
    %                   filename is [reachObject.RootSystemName, '_reachCoreachObject'],
    %                   that is the model name followed by
    %                   '_reachCoreachObject'. The file is saved as a .mat file. 
    %
    % Outputs:
    %   filename        Full path to the file with the saved data (same as input
    %                   if given).
    %
    % Example:
    %   Run Reach/Coreach from the context menu within a Simulink model.
    %   Save the Reach/Coreach results:
    %       reachSave = saveReachResults([]);
    %   Load the Reach/Coreach object and restore highlighting of blocks:
    %       reachObj = loadReachResults(reachSave, 1); % 2nd input triggers highlighting.
    %
    
    % Input Handling.
    if nargin < 1 || isempty(reachObj)
        reachObjName = [bdroot(gcs) '_reachCoreachObject'];
        eval(['global ' reachObjName ';']); % Get Reach/Coreach object in the workspace.
        eval(['reachObj = ' reachObjName ';'])
    end
    if nargin < 2
        filename = [reachObj.RootSystemName, '_reachCoreachObject'];
    end
    
    % 
    reachedObjectNames = {};
    for i = 1:length(reachObj.ReachedObjects)
        simObj = reachObj.ReachedObjects(i);
        if strcmp(get_param(simObj, 'Type'), 'block')
            reachedObjectNames{end+1} = getfullname(simObj);
        end % Lines saved in reachObject are not saved.
    end
    
    %
    coreachedObjectNames = {};
    for i = 1:length(reachObj.CoreachedObjects)
        simObj = reachObj.CoreachedObjects(i);
        if strcmp(get_param(simObj, 'Type'), 'block')
            coreachedObjectNames{end+1} = getfullname(simObj);
        end % Lines saved in reachObject are not saved.
    end
    
    % Save.
    save (filename, 'reachObj', 'reachedObjectNames', 'coreachedObjectNames');
end
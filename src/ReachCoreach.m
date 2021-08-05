classdef ReachCoreach < handle
    % REACHCOREACH A class that enables performing reachability/coreachability
    % analysis on blocks in a model.
    %
    %   A reachability analysis (reach) finds all blocks and lines that the
    %   given initial blocks affect via control flow or data flow. A
    %   coreachability analysis (coreach) finds all blocks and lines that affect
    %   the given initial blocks via control flow or data flow. After creating a
    %   ReachCoreach object, the reachAll and coreachAll methods can be used to
    %   perform these analyses respectively, and highlight all the
    %   blocks/lines in the reach and coreach.
    %
    % Example:
    %       open_system('ReachCoreachDemo_2011')
    %       r = ReachCoreach('ReachCoreachDemo_2011');
    %
    %   % Perform a reachability analysis:
    %       r.reachAll({'ReachCoreachDemo_2011/In2'},[]);
    %
    %   % Clear highlighting:
    %       r.clear();
    %
    %   % Change the highlighting colors
    %       r.setColor('blue', 'magenta')
    %
    %   % Perform a coreachability analysis:
    %       r.coreachAll({'ReachCoreachDemo_2011/Out2', {'ReachCoreachDemo_2011/Out3'},{});
    %
    %   % Perform a slice:
    %       r.slice();
    
    properties
        RootSystemName      % Simulink model name (or top-level system name).
        RootSystemHandle    % Handle of top level subsystem.
        
        ReachedObjects      % List of blocks and lines reached.
        CoreachedObjects    % List of blocks and lines coreached.
        
        TraversedPorts      % Ports already traversed in the reach operation.
        TraversedPortsCo    % Ports already traversed in the coreach operation.
        
        dsmMap              % Map of data store names to data store memory blocks
        dsrMap              % Map of data store names to data store read blocks
        dswMap              % Map of data store names to data store write blocks
        
        stvMap              % Map of goto tag names to goto tag visibility blocks
        sgMap               % Map of goto tag names to goto blocks
        sfMap               % Map of goto tag names to from blocks
        
        implicitMaps        % Struct of maps from tag/data store name to corresponding Froms, Gotos, TagVisibilities, Data Store Reads, Writes, and Memories
        returnToOpenSys     % Logical true if ReachCoreach should open back to the system that was open before analysis.
    end
    
    properties(Access = private)
        PortsToTraverse     % Ports remaining to traverse in the reach operation.
        PortsToTraverseCo   % Ports remaining to traverse in the coreach operation.
        
        RecurseCell         % Ports being reached in the main Reach loop
        
        Color               % Foreground color of highlight.
        BGColor             % Background color of highlight.
        
        dsmFlag             % Flag that determines uniqueness of DataStoreNames
        gtvFlag             % Flag that determines uniqueness of Goto Tags
        
        busCreatorBlockMap  % Map of all of the blocks a bused signal from a creator passes through
        busSelectorBlockMap % Map of all of the blocks a bused signal to a selector passes through
        
        busCreatorExitMap   % Map of all of the exits a bused signal from a creator passes through
        busSelectorExitMap  % Map of all of the exits a bused signal to a selector passes through
        
        ReachCoreachModels  % Models that have been reached or coreached
        MTraversedPorts     % Map of Travered ports for specific model references in the reach operation.
        MTraversedPortsCo   % Map of Travered ports for specific model references in the coreach operation.
        
        hiliteFlag          % Flag indicating whether to immediately highlight after a RCR operation
    end
    
    methods
        function object = ReachCoreach(RootSystemName)
            % REACHCOREACH Constructor for the ReachCoreach object.
            %
            %   Input:
            %       RootSystemName  Parameter name of the top level system in
            %                       the model hierarchy the reach/coreach
            %                       operations are to be run on.
            %
            %   Outputs:
            %       N/A
            %
            %   Example:
            %       obj = ReachCoreach('ModelName')
            
            % Check parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open
            try
                assert(ischar(RootSystemName));
                assert(bdIsLoaded(RootSystemName));
            catch
                error(['Error using ' mfilename ':' newline ...
                    'Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.'])
            end
            
            % 2) Ensure that the parameter given is the top level of the
            % model
            try
                assert(strcmp(RootSystemName, bdroot(RootSystemName)))
            catch
                error(['Error using ' mfilename ':' newline ...
                    'Invalid RootSystemName. Given RootSystemName is not ' ...
                    'the root level of its model.'])
            end
            
            % Initialize a new instance of ReachCoreach.
            % System and handle of the system ReachCoreach was called from
            object.RootSystemName = RootSystemName;
            object.RootSystemHandle = get_param(RootSystemName, 'handle');
            % Intialize containers as empty
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            object.dsmMap = containers.Map;
            object.dsrMap = containers.Map;
            object.dswMap = containers.Map;
            object.stvMap = containers.Map;
            object.sgMap = containers.Map;
            object.sfMap = containers.Map;
            object.busCreatorBlockMap = containers.Map();
            object.busSelectorBlockMap = containers.Map();
            object.busCreatorExitMap = containers.Map();
            object.busSelectorExitMap = containers.Map();
            object.MTraversedPorts = containers.Map();
            object.MTraversedPortsCo = containers.Map();
            % Setting flags
            object.gtvFlag = 1;
            object.dsmFlag = 1;
            object.hiliteFlag = 1;
            % Default Colours
            object.Color = 'red';
            object.BGColor = 'yellow';
            % List of models that were Reached/Coeached
            object.ReachCoreachModels = {object.RootSystemName}; % The modelled program was called from will always be Reached/Coeached
            object.implicitMaps = []; % Stays empty until all maps are set with findAllImplicitMappings
            object.returnToOpenSys = true;
            
            % Make a map of the scoped gotos by tag
%             temp = {};
            scopedGotos = find_system(RootSystemName, 'FollowLinks', 'on', ...
                'BlockType', 'Goto', 'TagVisibility', 'scoped');
            scopedGotos = [scopedGotos; find_system(RootSystemName, 'FollowLinks', 'on', ...
                'BlockType', 'Goto', 'TagVisibility', 'global')];
            for i=1:length(scopedGotos)
                tag = get_param(scopedGotos{i}, 'GotoTag');
%                 temp{end+1} = tag;
                try
                    object.sgMap(tag) = [object.sgMap(tag); scopedGotos{i}];
                catch
                    object.sgMap(tag) = {scopedGotos{i}};
                end
            end
            %             if (length(temp) == length(unique(temp)))&&(object.gtvFlag == 1)
            %                 object.gtvFlag = 1;
            %             else
            %                 object.gtvFlag = 0;
            %             end
            
            % Make a map of the scoped froms by tag
%             temp = {};
            scopedFroms = find_system(RootSystemName, 'FollowLinks', 'on', ...
                'BlockType', 'From');
            for i=1:length(scopedFroms)
                tag = get_param(scopedFroms{i}, 'GotoTag');
%                 temp{end+1} = tag;
                try
                    object.sfMap(tag) = [object.sfMap(tag); scopedFroms{i}];
                catch
                    object.sfMap(tag) = {scopedFroms{i}};
                end
            end
            %             if (length(temp) == length(unique(temp)))&&(object.gtvFlag == 1)
            %                 object.gtvFlag = 1;
            %             else
            %                 object.gtvFlag = 0;
            %             end
            
            % Make a map of the scoped tag visibility blocks by tag, and
            % additionally check for repeated scoped tag names
%             temp = {};
            scopedTags = find_system(RootSystemName, 'FollowLinks', 'on', ...
                'BlockType', 'GotoTagVisibility');
            for i=1:length(scopedTags)
                tag = get_param(scopedTags{i}, 'GotoTag');
%                 temp{end+1} = tag;
                try
                    object.stvMap(tag) = [object.stvMap(tag); scopedTags{i}];
                catch
                    object.stvMap(tag) = {scopedTags{i}};
                end
            end
            %             if (length(temp) == length(unique(temp)))&&(object.gtvFlag == 1)
            %                 object.gtvFlag = 1;
            %             else
            %                 object.gtvFlag = 0;
            %             end
            
            reads = find_system(RootSystemName, 'FollowLinks', 'on', ...
                'BlockType', 'DataStoreRead');
            for i=1:length(reads)
                dsName = get_param(reads{i}, 'DataStoreName');
                try
                    object.dsrMap(dsName) = [object.dsrMap(dsName); reads{i}];
                catch
                    object.dsrMap(dsName) = {reads{i}};
                end
            end
            
            writes = find_system(RootSystemName, 'FollowLinks', 'on', ...
                'BlockType', 'DataStoreWrite');
            for i=1:length(writes)
                dsName = get_param(writes{i}, 'DataStoreName');
                try
                    object.dswMap(dsName) = [object.dswMap(dsName); writes{i}];
                catch
                    object.dswMap(dsName) = {writes{i}};
                end
            end
            
%             temp = {};
            mems = find_system(RootSystemName, 'FollowLinks', 'on', ...
                'BlockType', 'DataStoreMemory');
            for i=1:length(mems)
                dsName = get_param(mems{i}, 'DataStoreName');
%                 temp{end+1} = dsName;
                try
                    object.dsmMap(dsName) = [object.dsmMap(dsName); mems{i}];
                catch
                    object.dsmMap(dsName) = {mems{i}};
                end
            end
            %             if (length(temp) == length(unique(temp)))
            %                 object.dsmFlag = 1;
            %             else
            %                 object.dsmFlag = 0;
            %             end
        end

        function [fgcolor, bgcolor] = getColor(object)
            % GETCOLOR Get the highlight colours for the reach/coreach.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %
            %   Outputs:
            %       fgcolor Foreground colour.
            %       bgcolor Background colour.
            %
            %   Example:
            %       obj.getColor()
            fgcolor = object.Color;
            bgcolor = object.BGColor;
        end
        
        function setColor(object, color1, color2)
            % SETCOLOR Set the highlight colours for the reach/coreach.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %       color1  Parameter for the highlight foreground colour.
            %               Accepted values are 'red', 'green', 'blue', 'cyan',
            %               'magenta', 'yellow', 'black', 'white'.
            %
            %       color2  Parameter for the highlight background colour.
            %               Accepted values are 'red', 'green', 'blue', 'cyan',
            %               'magenta', 'yellow', 'black', 'white'.
            %
            %   Outputs:
            %       N/A
            %
            %   Example:
            %       obj.setColor('red', 'blue')
            
            % Ensure that the parameters are strings
            try
                assert(ischar(color1))
                assert(ischar(color2))
            catch
                error(['Error using ' mfilename ':' newline ...
                    ' Invalid color(s). Accepted colors are ''red'', ''green'', ' ...
                    '''blue'', ''cyan'', ''magenta'', ''yellow'', ''white'', and ''black''.'])
            end
            
            % Ensure that the colours selected are acceptable
            try
                acceptedColors = {'cyan', 'red', 'blue', 'green', 'magenta', ...
                    'yellow', 'white', 'black'};
                assert(isempty(setdiff(color1, acceptedColors)))
                assert(isempty(setdiff(color2, acceptedColors)))
            catch
                error(['Error using ' mfilename ':' newline ...
                    ' Invalid color(s). Accepted colours are ''red'', ''green'', ' ...
                    '''blue'', ''cyan'', ''magenta'', ''yellow'', ''white'', and ''black''.'])
            end
            % Record current open system
            initialOpenSystem = gcs;
            
            % Set the desired colours for highlighting
            object.Color = color1;
            object.BGColor = color2;
            
            returnToWindow(object, initialOpenSystem);
        end
        
        function setHiliteFlag(object, flag)
            % SETHILITEFLAG Set hiliteFlag object property. Determines whether
            % to hilite objects or not.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %       flag    Boolean value to set the flag to.
            %
            %   Outputs:
            %       N/A
            %
            %   Example:
            %       obj.setHiliteFlag(true)
            
            if flag == 0
                object.hiliteFlag = flag;
            else
                object.hiliteFlag = 1;
            end
        end
        
        function hiliteObjects(object)
            % HILITEOBJECTS Highlight the reached/coreached blocks and lines.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %
            %   Outputs:
            %       N/A
            %
            %   Example:
            %       obj.hiliteObjects()
            
            % Keep track of currently opened windows
            openSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            
            % Hilite reached/coreached elements
            HILITE_DATA = struct('HiliteType', 'user2', 'ForegroundColor', object.Color, 'BackgroundColor', object.BGColor);
            set_param(0, 'HiliteAncestorsData', HILITE_DATA);
            warningID = 'Simulink:blocks:HideContents';
            warning('off', warningID);
            % Clear previous hilite (Fix for 2016b)
            hilite_system_notopen(object.ReachedObjects, 'none');
            hilite_system_notopen(object.CoreachedObjects, 'none');
            % Apply new hilite
            hilite_system_notopen(object.ReachedObjects, 'user2');
            hilite_system_notopen(object.CoreachedObjects, 'user2');
            warning('on', warningID);
            
            % Close windows that weren't open before
            allOpenSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            sysToClose = setdiff(allOpenSys, openSys);
            close_system(sysToClose); % Close Simulink systems
            sfclose('all'); % Close Stateflow
        end
        
        function slice(object)
            % SLICE Isolate the reached/coreached blocks by removing
            % unhighlighted blocks.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %
            %   Outputs:
            %       N/A
            %
            %   Example:
            %       obj.slice()
            
            % Ensure that there is a selection before slicing.
            try
                assert(~isempty(object.ReachedObjects)||~isempty(object.CoreachedObjects))
            catch
                error(['Error using ' mfilename ':' newline ...
                    ' There are no reached/coreached objects' ...
                    ' to slice.'])
            end
            
            % Record current open system
            initialOpenSystem = gcs;
            
            openSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            
            % Remove links
            subsystems = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'SubSystem');
            for i = 1:length(subsystems)
                linkStatus = get_param(subsystems{i}, 'LinkStatus');
                if strcmp(linkStatus, 'resolved')
                    set_param(subsystems{i}, 'LinkStatus', 'inactive');
                elseif strcmp(linkStatus, 'implicit')
                    % If a subsystem higher in the hierarchy is linked
                    % find it and make link inactive
                    flag = 1;
                    linkedSys = subsystems{i};
                    while flag
                        linkedSys = get_param(linkedSys, 'parent');
                        linkStatus = get_param(linkedSys, 'LinkStatus');
                        if strcmp(linkStatus, 'resolved')
                            set_param(linkedSys, 'LinkStatus', 'inactive');
                            flag = 0;
                        end
                    end
                end
            end
            
            allBlocks = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'block');
            toKeep = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line', 'HiliteAncestors', 'user2');
            toKeep = [toKeep; find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'block', 'HiliteAncestors', 'user2')];
            
            blocksToDelete = setdiff(allBlocks, toKeep);
            warningID = 'MATLAB:DELETE:FileNotFound';
            warning('off', warningID);
            
            for i = 1:length(blocksToDelete)
                try
                    delete_block(blocksToDelete(i));
                catch E
                    if ~strcmp(E.identifier, 'Simulink:Commands:InvSimulinkObjHandle')
                        error(E);
                    end
                end
            end
            
            allLines = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line');
            linesToDelete = setdiff(allLines, toKeep);
            for i = 1:length(linesToDelete)
                try
                    delete_block(linesToDelete(i));
                catch E
                    if ~strcmp(E.identifier, 'Simulink:Commands:InvSimulinkObjHandle')
                        error(E);
                    end
                end
            end
            
            warning('on', warningID);
            brokenLines = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line', 'DstBlockHandle', -1);
            brokenLines = [brokenLines; find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line', 'SrcBlockHandle', -1)];
            delete_line(brokenLines);
            
            %ground unconnected lines
            GroundAndTerminatePorts(object.RootSystemName);
            
            subsToCheck = find_system(object.RootSystemName, 'BlockType', 'SubSystem');
            for i = 1:length(subsToCheck)
                GroundAndTerminatePorts(subsToCheck{i});
            end
            
            allOpenSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            sysToClose = setdiff(allOpenSys, openSys);
            close_system(sysToClose);
            sfclose('all');
            
            object.clear();
            
            if ~isempty(find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Name', initialOpenSystem))
                returnToWindow(object, initialOpenSystem);
            end
        end
        
        function clear(object)
            % CLEAR Remove all reach/coreach highlighting.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %
            %   Outputs:
            %       N/A
            %
            %   Example:
            %       obj.clear()
            
            % Record current open system
            initialOpenSystem = gcs;
            
            % Clear highlighting
            for i = 1:length(object.ReachCoreachModels) % For each model loaded
                % Find systems and blocks to be highlighted
                openSys = find_system(object.ReachCoreachModels{i}, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
                hilitedObjects = find_system(object.ReachCoreachModels{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line', 'HiliteAncestors', 'user2');
                hilitedObjects = [hilitedObjects; find_system(object.ReachCoreachModels{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'block', 'HiliteAncestors', 'user2')];
                % Sets highlight type to none (clears highlighting)
            hilite_system_notopen(hilitedObjects, 'none');
                
                % Close systems
                allOpenSys = find_system(object.ReachCoreachModels{i}, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
                sysToClose = setdiff(allOpenSys, openSys);
                close_system(sysToClose);
            end
            
            % Reset containers
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            object.TraversedPorts = [];
            object.TraversedPortsCo = [];
            
            object.busCreatorBlockMap  = containers.Map;
            object.busSelectorBlockMap = containers.Map;
            object.busCreatorExitMap = containers.Map;
            object.busSelectorExitMap = containers.Map;
            
            object.ReachCoreachModels = {object.RootSystemName};
            object.MTraversedPorts = containers.Map('KeyType','char','ValueType','any');
            object.MTraversedPortsCo = containers.Map('KeyType','char','ValueType','any');
            
            % Return to correct window
            returnToWindow(object, initialOpenSystem);
        end
        
        function reachAll(object, selection, selLines)
            % REACHALL Perform a reach operation on the blocks selected.
            % The reach operation is started by this function
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       selection   Cell array of strings representing the full
            %                   names of blocks.
            %       selLines    Array of line handles.
            %
            %   Outputs:
            %       N/A
            %
            %   Example:
            %       obj.reachAll({'ModelName/In1', 'ModelName/SubSystem/Out2'}, [])
            
            % Check object parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open
            try
                assert(ischar(object.RootSystemName));
                assert(bdIsLoaded(object.RootSystemName));
            catch
                error(['Error using ' mfilename ':' newline ...
                    ' Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.'])
            end
            
            % 2) Check that model M is unlocked
            %             try
            %                 assert(strcmp(get_param(bdroot(object.RootSystemName), 'Lock'), 'off'))
            %             catch E
            %                 if strcmp(E.identifier, 'MATLAB:assert:failed') || ...
            %                         strcmp(E.identifier, 'MATLAB:assertion:failed')
            %                     error(['Error using ' mfilename ':' newline ...
            %                         ' File is locked.'])
            %                 else
            %                     error(['Error using ' mfilename ':' newline ...
            %                         ' Invalid RootSystemName.'])
            %                 end
            %             end
            
            % Check that selection is of type 'cell'
            try
                assert(iscell(selection));
            catch
                error(['Error using ' mfilename ':' newline ...
                    ' Invalid cell argument "selection".'])
            end
            
            % Record current open system
            initialOpenSystem = gcs;
            
            % If Initial Reach Selection is special port
            % Get the ports/blocks of selected blocks that are special
            % cases
            for i = 1:length(selection)
                % Check that the elements of selection are existing blocks
                % in model RootSystemName
                try
                    assert(strcmp(get_param(selection{i}, 'type'), 'block'));
                    assert(strcmp(bdroot(selection{i}), object.RootSystemName));
                catch
                    disp(['Error using ' mfilename ':' newline ...
                        selection{i} ' is not a block in system ' object.RootSystemName '.'])
                    break
                end
                
                selectionType = get_param(selection{i}, 'BlockType');
                
                % Case statement
                if strcmp(selectionType, 'SubSystem')
                    % Get all outgoing interface items from the subsystem, and add
                    % blocks to reach, as well as outports to the list of ports
                    % to traverse
                    outBlocks = object.getInterfaceOut(selection{i});
                    for j = 1:length(outBlocks)
                        object.ReachedObjects(end + 1) = get_param(outBlocks{j}, 'handle');
                        ports = get_param(outBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    
                    % Add all blocks within the subsystem into the list of items
                    % already traced
                    moreBlocks = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                    for j = 1:length(moreBlocks)
                        object.ReachedObjects(end + 1) = get_param(moreBlocks{j}, 'handle');
                    end
                    
                    % If it's a Simulink Function, find its matching
                    % Function Caller blocks. Add the Callers to the list of items
                    % traced, and add their outports to the list of items to
                    % continue tracing from
                    if isSimulinkFcn(selection{i})
                        callers = matchSimFcn(selection{i});
                        for j = 1:length(callers)
                            object.ReachedObjects(end + 1) = get_param(callers{j}, 'handle');
                            ports = get_param(callers{j}, 'PortHandles');
                            object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                        end
                    end
                    
                    % Add lines
                    selLines = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
                    object.ReachedObjects = [object.ReachedObjects selLines.'];
                    
                    % Add ports that aren't output of input ports to the
                    % list of traversed ports
                    morePorts = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'port');
                    if iscolumn(morePorts)
                        morePorts = morePorts.';
                    end
                    portsToExclude = get_param(selection{i}, 'PortHandles');
                    portsToExclude = portsToExclude.Outport;
                    morePorts = setdiff(morePorts, portsToExclude);
                    object.TraversedPorts = [object.TraversedPorts morePorts];
                    
                elseif strcmp(selectionType, 'FunctionCaller')
                    % Find the Simulink Function and add it and its contents to the reach list.
                    % Add any outports that the Simulink Function may have to
                    % the list of items to traverse.
                    fcn = matchSimFcn(selection{i});
                    if iscell(fcn) && length(fcn) > 1 % Should only be 1, but just in case, we check
                        fcn = fcn{1};
                    end
                    object.ReachedObjects(end + 1) = get_param(fcn, 'handle');
                    ports = get_param(fcn, 'PortHandles');
                    object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    
                    % Add contents
                    % 1) Any outgoing implicit interface items to the subsystem
                    outBlocks = object.getInterfaceOut(fcn);
                    for j = 1:length(outBlocks)
                        object.ReachedObjects(end + 1) = get_param(outBlocks{j}, 'handle');
                        ports = get_param(outBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    
                    % 2) Contained blocks
                    moreBlocks = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                    for j = 1:length(moreBlocks)
                        object.ReachedObjects(end + 1) = get_param(moreBlocks{j}, 'handle');
                    end
                    
                    % 3) Contained lines
                    lines = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
                    object.ReachedObjects = [object.ReachedObjects lines.'];
                    
                elseif strcmp(selectionType, 'Outport')
                    portNum = get_param(selection{i}, 'Port');
                    parent = get_param(selection{i}, 'parent');
                    % If Output port leaves subsystem, find parent and
                    % Reach on the parent's port
                    if ~isempty(get_param(parent, 'parent'))
                        % Get ports going out of element
                        portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2double(portNum));
                        bus_elements = get_param(selection{i},'Element'); % Get bus elements if they exist
                        if ~isempty(bus_elements) % If the bus elements aren't empty, then using Out Bus elements
                            % If it leaves via a bus
                            % Parse element signal into its proper form
                            tmpsignal = split(string(bus_elements),'.');
                            if length(tmpsignal) <= 1
                                % Single level bus
                                signalName = tmpsignal;
                            else
                                % Multi level buses
                                signalName = cell(1,length(tmpsignal));
                                signalName{1} = tmpsignal{end};
                                for j = 2:length(tmpsignal)
                                    signalName{j} = strcat(tmpsignal{end-j+1},'.',signalName{j-1});
                                end
                            end
                            % Traverse Bus
                            [path, exit] = object.traverseBusForwardsHandler(selection{i}, portSub, signalName, object.RootSystemName);
                            object.TraversedPorts = [object.TraversedPorts path];
                            blockList = object.busCreatorBlockMap;
                            blockList = blockList(selection{i});
                            object.ReachedObjects = [object.ReachedObjects blockList];
                            object.PortsToTraverse = [object.PortsToTraverse exit];
                            % empty buffers
                            remove(object.busCreatorBlockMap, selection{i});
%                             remove(object.busSelectorExitMap, selection{i});
                        else
                            % If it leaves normally
                        object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                        object.PortsToTraverse(end + 1) = portSub;
                    end
                    end
                    
                elseif strcmp(selectionType, 'Inport')
                    % Entering into variant subsystem needs special case
                    parent = get_param(selection{i}, 'parent');
                    if ~strcmp(get_param(selection{i}, 'parent'), object.RootSystemName) && strcmp(get_param(parent, 'BlockType'), "SubSystem")
                        isVariantParent = get_param(parent, 'Variant');
                        if strcmp(isVariantParent, 'on') 
                             % Find Child Subsystem inside Variant
                             % Subsystem and add matching port and selected
                             % inport to reach
                             portNum = get_param(selection{i}, 'Port');
                             childSub = find_system(parent, 'SearchDepth', 1,'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                 'BlockType', 'SubSystem');
                             portSub = find_system(childSub{2}, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                 'BlockType', 'Inport', 'Port', num2str(portNum));
                             PortHandle = get_param(portSub, 'handle');
                             object.ReachedObjects(end + 1) = get_param(selection{i}, 'handle');
                             object.ReachedObjects(end + 1) = get_param(childSub{2}, 'handle');
                             selection{i} = PortHandle{1};
                        end
                    end
                    
                elseif strcmp(selectionType, 'GotoTagVisibility')
                    % Add Goto and From blocks to reach, and ports to list to traverse
                    associatedBlocks = findGotoFromsInScopeRCR(object, selection{i}, object.gtvFlag);
                    for j = 1:length(associatedBlocks)
                        object.ReachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    
                elseif strcmp(selectionType, 'DataStoreMemory')
                    % Add Read and Write blocks to reach, and ports to list
                    % to traverse
                    associatedBlocks = findReadWritesInScopeRCR(object, selection{i}, object.dsmFlag);
                    for j = 1:length(associatedBlocks)
                        object.ReachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    
                elseif strcmp(selectionType, 'DataStoreWrite')
                    % Add Read blocks to reach, and ports to list to traverse
                    reads = findReadsInScopeRCR(object, selection{i}, object.dsmFlag);
                    for j = 1:length(reads)
                        object.ReachedObjects(end + 1) = get_param(reads{j}, 'handle');
                        ports = get_param(reads{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    mem = findDataStoreMemoryRCR(object, selection{i}, object.dsmFlag);
                    if ~isempty(mem)
                        object.ReachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                    end
                    
                elseif strcmp(selectionType, 'DataStoreRead')
                    mem = findDataStoreMemoryRCR(object, selection{i}, object.dsmFlag);
                    if ~isempty(mem)
                        object.ReachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                    end
                    
                elseif strcmp(selectionType, 'Goto')
                    % Add from blocks to reach, and ports to list to traverse
                    froms = findFromsInScopeRCR(object, selection{i}, object.gtvFlag);
                    for j = 1:length(froms)
                        object.ReachedObjects(end + 1) = get_param(froms{j}, 'handle');
                        ports = get_param(froms{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    tag = findVisibilityTagRCR(object, selection{i}, object.gtvFlag);
                    if ~isempty(tag)
                        object.ReachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                    end
                    
                elseif strcmp(selectionType, 'From')
                    tag = findVisibilityTagRCR(object, selection{i}, object.gtvFlag);
                    if ~isempty(tag)
                        object.ReachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                    end
                    
                elseif strcmp(selectionType, 'BusCreator')
                    % Start bus traversal on each of the bus creator ports
                    busInports = get_param(selection{i}, 'PortHandles');
                    busInports = busInports.Inport;
                    for j = 1:length(busInports)
                        line = get_param(busInports(j), 'line');
                        signalName = get_param(line, 'Name');
                        if isempty(signalName) % Default signal name
                            portNum = get_param(busInports(j), 'PortNumber');
                            signalName = ['signal' num2str(portNum)];
                        end
                        busPort = get_param(selection{i}, 'PortHandles');
                        busPort = busPort.Outport;
                        % Traverse bus
                        [path, exit] = object.traverseBusForwardsHandler(selection{i}, busPort, {signalName}, object.RootSystemName);
                        object.TraversedPorts = [object.TraversedPorts path];
                        blockList = object.busCreatorBlockMap;
                        blockList = blockList(selection{i});
                        object.ReachedObjects = [object.ReachedObjects blockList];
                        object.PortsToTraverse = [object.PortsToTraverse exit];
                        % empty buffers
                        remove(object.busCreatorBlockMap, selection{i});
%                         remove(object.busSelectorExitMap, selection{i});
                    end
                    
                elseif (strcmp(selectionType, 'EnablePort') || ...
                        strcmp(selectionType, 'ActionPort') || ...
                        strcmp(selectionType, 'TriggerPort') || ...
                        strcmp(selectionType, 'WhileIterator') || ...
                        strcmp(selectionType, 'ForEach') || ...
                        strcmp(selectionType, 'ForIterator'))
                    % Add everything in a subsystem to the reach if one
                    % of the listed block types is in the selection
                    object.reachEverythingInSub(get_param(selection{i}, 'parent'))
                    
                elseif (strcmp(selectionType, 'SliderSwitchBlock') || ...
                        strcmp(selectionType, 'KnobBlock') || ...
                        strcmp(selectionType, 'LampBlock'))
                    % Interface elements
                    binding = get_param(selection{i}, 'binding');
                    blockPath = binding.BlockPath;
                    connectedPath = getBlock(blockPath, 1);
                    object.ReachedObjects(end + 1) = get_param(selection{i}, 'handle');
                    selection{i} = connectedPath;
                end
                % Add blocks to reach from selection, and their ports to the
                % list to traverse
                
                % Default case
                object.ReachedObjects(end + 1) = get_param(selection{i}, 'handle');
                ports = get_param(selection{i}, 'PortHandles');
                object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
            end
            
            for i = 1:length(selLines)
                assert(isempty(object.PortsToTraverse) || iscolumn(object.PortsToTraverse) || isrow(object.PortsToTraverse))

                srcPort = get_param(selLines(i), 'SrcPortHandle');
                assert(length(srcPort) == 1)
                
                if iscolumn(object.PortsToTraverse)
                    object.PortsToTraverse = [object.PortsToTraverse; srcPort];
                else % isrow
                    object.PortsToTraverse = [object.PortsToTraverse, srcPort];
                end
            end
            
            % Actual reach process happends in this loop
            % Reach from each in the list of ports to traverse
            while ~isempty(object.PortsToTraverse)
                object.RecurseCell = setdiff(object.PortsToTraverse, object.TraversedPorts);
                object.PortsToTraverse = [];
                while ~isempty(object.RecurseCell)
                    port = object.RecurseCell(end);
                    object.RecurseCell(end) = [];
                    reach(object, port, object.RootSystemName);
                end
                %object.PortsToTraverse = setdiff(object.PortsToTraverse, object.TraversedPorts);
            end
            
            % Get foreach blocks
            forEach = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ForEach');
            for i = 1:length(forEach)
                system = get_param(forEach{i}, 'parent');
                sysObjects = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects = setdiff(sysObjects, get_param(system, 'handle'));
                if ~isempty(intersect(sysObjects, object.ReachedObjects))
                    if isempty(intersect(get_param(forEach{i}, 'Handle'), object.ReachedObjects))
                        object.ReachedObjects(end + 1) = get_param(forEach{i}, 'Handle');
                    end
                end
            end
            
            % Highlight all objects reached
            if object.hiliteFlag
                object.hiliteObjects();
            end
            
            % Return to main window
            returnToWindow(object, initialOpenSystem);
        end
        
        function coreachAll(object, selection, selLines)
            % COREACHALL Perform a coreach operation on the blocks selected.
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       selection   Cell array of strings representing the full
            %                   names of blocks.
            %       selLines    Array of line handles.
            %
            %   Outputs:
            %       N/A
            %
            %   Example:
            %       obj.coreachAll({'ModelName/In1', 'ModelName/SubSystem/Out2'})
            
            % Check object parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open
            try
                assert(ischar(object.RootSystemName));
                assert(bdIsLoaded(object.RootSystemName));
            catch
                error(['Error using ' mfilename ':' newline ...
                    ' Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.'])
            end
            
            % Check that selection is of type 'cell'
            try
                assert(iscell(selection));
            catch
                error(['Error using ' mfilename ':' newline ...
                    ' Invalid cell argument "selection".'])
            end
            
            % Record current open system
            initialOpenSystem = gcs;
            
            % If Initial CoReach Selection is special port
            % Get the ports/blocks of selected blocks that are special
            % cases
            for i = 1:length(selection)
                % Check that the elements of selection are existing blocks
                % in model RootSystemName
                try
                    assert(strcmp(get_param(selection{i}, 'type'), 'block'));
                    assert(strcmp(bdroot(selection{i}), object.RootSystemName));
                catch
                    disp(['Error using ' mfilename ':' newline ...
                        selection{i} ' is not a block in system ' object.RootSystemName '.'])
                    break
                end
                selectionType = get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    % Get all incoming interface items to the subsystem, and add
                    % blocks to coreach, as well as inports to the list of ports
                    % to traverse
                    inBlocks = object.getInterfaceIn(selection{i});
                    for j = 1:length(inBlocks)
                        object.CoreachedObjects(end + 1) = get_param(inBlocks{j}, 'handle');
                        ports = get_param(inBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    
                    % If it's a Simulink Function, find its matching
                    % Function Caller blocks. Add the Callers to the list of items
                    % traced, and add their inports to the list of items to
                    % continue tracing from
                    if isSimulinkFcn(selection{i})
                        callers = matchSimFcn(selection{i});
                        for j = 1:length(callers)
                            object.ReachedObjects(end + 1) = get_param(callers{j}, 'handle');
                            ports = get_param(callers{j}, 'PortHandles');
                            object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                        end
                    end

                    % Add all blocks within the subsystem into the list of items
                    % already traced
                    moreBlocks = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                    for j = 1:length(moreBlocks)
                        object.CoreachedObjects(end + 1) = get_param(moreBlocks{j}, 'handle');
                    end
                    
                    % Add lines
                    lines = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
                    object.CoreachedObjects = [object.CoreachedObjects lines.'];
               
                elseif strcmp(selectionType, 'FunctionCaller')
                    % Find the Simulink Function and add it and its contents to the coreach list.
                    % Add any inports that the Simulink Function may have to
                    % the list of items to traverse.
                    fcn = matchSimFcn(selection{i});
                    if iscell(fcn) && length(fcn) > 1 % Should only be 1, but just in case, we check
                        fcn = fcn{1};
                    end
                    object.CoreachedObjects(end + 1) = get_param(fcn, 'handle');
                    ports = get_param(fcn, 'PortHandles');
                    object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    
                    % Add contents
                    % 1) Any incoming implicit interface items to the subsystem
                    inBlocks = object.getInterfaceIn(fcn);
                    for j = 1:length(inBlocks)
                        object.CoreachedObjects(end + 1) = get_param(inBlocks{j}, 'handle');
                        ports = get_param(inBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    
                    % 2) Contained blocks
                    moreBlocks = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                    for j = 1:length(moreBlocks)
                        object.CoreachedObjects(end + 1) = get_param(moreBlocks{j}, 'handle');
                    end
                    
                    % 3) Contained lines
                    lines = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
                    object.CoreachedObjects = [object.CoreachedObjects lines.'];
                    morePorts = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'port');
                    if iscolumn(morePorts)
                        morePorts = morePorts.';
                    end
                    portsSub = get_param(fcn, 'PortHandles');
                    portsToExclude = [portsSub.Inport portsSub.Trigger portsSub.Enable portsSub.Ifaction];
                    morePorts = setdiff(morePorts, portsToExclude);
                    object.TraversedPortsCo = [object.TraversedPortsCo morePorts];
                    
                elseif strcmp(selectionType, 'Inport')
                    portNum = get_param(selection{i}, 'Port');
                    parent = get_param(selection{i}, 'parent');
                    % If inport exits to parent above, start Coreach on
                    % inport port located in parent
                    if ~isempty(get_param(parent, 'parent'))
                        portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2double(portNum));
                        bus_elements = get_param(selection{i},'Element'); % Get bus elements if they exist
                        if ~isempty(bus_elements) % If the bus elements aren't empty, then using In Bus elements
                            % Bus traversal Inport case
                            % Parse bus element signal
                            tmpsignal = split(string(bus_elements),'.');
                            if length(tmpsignal) <= 1
                                % Single level buses
                                signalName = tmpsignal;
                            else
                                % Multi level buses
                                signalName = cell(1,length(tmpsignal));
                                signalName{1} = tmpsignal{end};
                                for j = 2:length(tmpsignal)
                                    signalName{j} = tmpsignal{end-j+1};
                                end
                            end
                            % Coreach Bus traversal
                            [path, blockList, exit] = object.traverseBusBackwardsHandler(portSub, signalName, object.RootSystemName);
                            object.TraversedPortsCo = [object.TraversedPortsCo path];
                            object.CoreachedObjects = [object.CoreachedObjects blockList];
                            object.PortsToTraverseCo = [object.PortsToTraverseCo exit];
                        else
                            % Normal case
                        object.CoreachedObjects(end + 1) = get_param(parent, 'handle');
                        object.PortsToTraverseCo(end + 1) = portSub;
                    end
                    end
                    
                elseif strcmp(selectionType, 'Outport')
                    % Entering into variant subsystem needs special case
                    ParentBlock = get_param(selection{i}, 'parent');
                    if ~strcmp(get_param(selection{i}, 'parent'), object.RootSystemName) && strcmp(get_param(ParentBlock, 'BlockType'), "SubSystem")
                        isVariantParent = get_param(ParentBlock, 'Variant');
                        if strcmp(isVariantParent, 'on') 
                             % Find Child Subsystem inside Variant
                             % Subsystem and add matching port and the 
                             % selected output to coreach
                             portNum = get_param(selection{i}, 'Port');
                             childSub = find_system(ParentBlock, 'SearchDepth', 1,'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                 'BlockType', 'SubSystem');
                             portSub = find_system(childSub{2}, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                 'BlockType', 'Outport', 'Port', num2str(portNum));
                             PortHandle = get_param(portSub, 'handle');
                             object.CoreachedObjects(end + 1) = get_param(selection{i}, 'handle');
                             object.CoreachedObjects(end + 1) = get_param(childSub{2}, 'handle');
                             selection{i} = PortHandle{1};
                        end
                    end
                    
                elseif strcmp(selectionType, 'GotoTagVisibility')
                    % Add Goto and From blocks to coreach, and ports to list to
                    % traverse
                    associatedBlocks = findGotoFromsInScopeRCR(object, selection{i}, object.gtvFlag);
                    for j = 1:length(associatedBlocks)
                        object.CoreachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    
                elseif strcmp(selectionType, 'DataStoreMemory')
                    % Add Read and Write blocks to coreach, and ports to list
                    % to traverse
                    associatedBlocks = findReadWritesInScopeRCR(object, selection{i}, object.dsmFlag);
                    for j = 1:length(associatedBlocks)
                        object.CoreachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    
                elseif strcmp(selectionType, 'From')
                    % Add Goto blocks to coreach, and ports to list to
                    % traverse
                    gotos = findGotosInScopeRCR(object, selection{i}, object.gtvFlag);
                    for j = 1:length(gotos)
                        object.CoreachedObjects(end + 1) = get_param(gotos{j}, 'handle');
                        ports = get_param(gotos{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    tag = findVisibilityTagRCR(object, selection{i}, object.gtvFlag);
                    if ~isempty(tag)
                        object.CoreachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                    end
                    
                elseif strcmp(selectionType, 'Goto')
                    tag = findVisibilityTagRCR(object, selection{i}, object.gtvFlag);
                    if ~isempty(tag)
                        object.CoreachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                    end
                    
                elseif strcmp(selectionType, 'DataStoreRead')
                    % Add Write blocks to coreach, and ports to list to
                    % traverse
                    writes = findWritesInScopeRCR(object, selection{i}, object.dsmFlag);
                    for j = 1:length(writes)
                        object.CoreachedObjects(end + 1) = get_param(writes{j}, 'handle');
                        ports = get_param(writes{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    mem = findDataStoreMemoryRCR(object, selection{i}, object.dsmFlag);
                    if ~isempty(mem)
                        object.CoreachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                    end
                    
                elseif strcmp(selectionType, 'DataStoreWrite')
                    mem = findDataStoreMemoryRCR(object, selection{i}, object.dsmFlag);
                    if ~isempty(mem)
                        object.CoreachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                    end
                    
                elseif strcmp(selectionType, 'BusSelector')
                    % Start bus traversal on inport ports of BusSelector
                    busOutports = get_param(selection{i}, 'PortHandles');
                    busOutports = busOutports.Outport;
                    for j = 1:length(busOutports)
                        portNum = get_param(busOutports(j), 'PortNumber');
                        signal = get_param(selection{i}, 'OutputSignals');
                        signal = regexp(signal, ',', 'split');
                        signal = signal{portNum};
                        busPort=get_param(selection{i}, 'PortHandles');
                        % Coreach Bus traversal
                        [path, blockList, exit] = object.traverseBusBackwardsHandler(busPort.Inport, {signal}, object.RootSystemName);
                        object.TraversedPortsCo = [object.TraversedPortsCo path];
                        object.CoreachedObjects = [object.CoreachedObjects blockList];
                        object.PortsToTraverseCo = [object.PortsToTraverseCo exit];
                    end
                    
                elseif strcmp(selectionType, 'TriggerPort')
                    parent = get_param(selection{i}, 'parent');
                    portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                        'type', 'port', 'parent', parent, 'PortType', 'trigger');
                    object.PortsToTraverseCo = [object.PortsToTraverseCo portSub];
                    
                elseif strcmp(selectionType, 'EnablePort')
                    parent = get_param(selection{i}, 'parent');
                    portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                        'type', 'port', 'parent', parent, 'PortType', 'enable');
                    object.PortsToTraverseCo = [object.PortsToTraverseCo portSub];
                    
                elseif strcmp(selectionType, 'ActionPort')
                    parent = get_param(selection{i}, 'parent');
                    portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                        'type', 'port', 'parent', parent, 'PortType', 'ifaction');
                    object.PortsToTraverseCo = [object.PortsToTraverseCo portSub];
                    
                elseif strcmp(selectionType, 'WhileIterator') || strcmp(selectionType, 'ForIterator') || strcmp(selectionType, 'ForEach')
                    toCoreach = getInterfaceOut(object, get_param(selection{i}, 'parent'));
                    for j = 1:length(toCoreach)
                        ports = get_param(toCoreach{j}, 'PortHandles');
                        object.CoreachedObjects(end+1) = get_param(toCoreach{j}, 'Handle');
                        inports = ports.Inport;
                        for k = 1:length(inports)
                            object.PortsToTraverseCo(end + 1) = inports(k);
                        end
                    end
                    ins = find_system(get_param(selection{i}, 'parent'), 'SearchDepth', 1, 'BlockType', 'Outport');
                    for j = 1:length(ins)
                        ports = get_param(ins{j}, 'PortHandles');
                        object.CoreachedObjects(end+1) = get_param(ins{j}, 'Handle');
                        inports = ports.Inport;
                        for k = 1:length(inports)
                            object.PortsToTraverseCo(end + 1) = inports(k);
                        end
                    end
                end
                
                % Default case
                % Add blocks to coreach from selection, and their ports to the
                % list to traverse
                object.CoreachedObjects(end + 1) = get_param(selection{i}, 'handle');
                ports = get_param(selection{i}, 'PortHandles');
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Enable];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Trigger];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Ifaction];
            end
            
            for i = 1:length(selLines)
                assert(isempty(object.PortsToTraverseCo) || iscolumn(object.PortsToTraverseCo) || isrow(object.PortsToTraverseCo))
                
                dstPorts = get_param(selLines(i), 'DstPortHandle');
                assert(iscolumn(dstPorts) || isrow(dstPorts))
                
                if iscolumn(object.PortsToTraverseCo)
                    if isrow(dstPorts)
                        dstPorts = dstPorts';
                    end
                    object.PortsToTraverseCo = [object.PortsToTraverseCo; dstPorts];
                else % isrow
                    if iscolumn(dstPorts)
                        dstPorts = dstPorts';
                    end
                    object.PortsToTraverseCo = [object.PortsToTraverseCo, dstPorts];
                end
            end
            
            flag = true;
            while flag
                % Actual reach process happends in this loop
                % Coreach from each in the list of ports to traverse
                while ~isempty(object.PortsToTraverseCo)
                    port = object.PortsToTraverseCo(end);
                    object.PortsToTraverseCo(end) = [];
                    coreach(object, port, object.RootSystemName);
                end
                % Add any iterators in the coreach to blocks coreached and
                % their ports to list to traverse
                iterators = findIterators(object);
                if ~isempty(iterators)
                    for i = 1:length(iterators)
                        ports = get_param(iterators{i}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo, ports.Inport];
                        object.CoreachedObjects(end + 1) = get_param(iterators{i}, 'Handle');
                    end
                end
                % Add any trigger, enable, or action ports and their
                % respective blocks to the coreach and their ports to the
                % list to traverse
                object.findSpecialPorts();
                % Keep iterating through until there are no more
                % blocks/ports being added
                if isempty(object.PortsToTraverseCo)
                    flag = false;
                end
            end
            
            % Highlight the coreached objects
            if object.hiliteFlag
                object.hiliteObjects();
            end
            
            % Return to main window
            returnToWindow(object, initialOpenSystem);
        end
        
        function findAllImplicitMappings(object, verbose, cpool, coreNum)
            % FINDALLIMPLICITMAPPINGS Finds mappings from each block with
            % implicit connections to the blocks they connect with.
            % 
            % Inputs:
            %   object  ReachCoreachObject
            %   verbose [Optional] Logical true to display progress updates in
            %           the command line.
            
            if nargin < 4
                verbose = false;
            end
            
            if verbose
                disp(['Begin finding implicit mappings in ' object.RootSystemName])
                disp('Step 1/7: Finding blocks with implicit connections.')
            end
            scopedGotos = find_system(object.RootSystemName, ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'BlockType', 'Goto');
%             scopedGotos = find_system(RootSystemName, ...
%                 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
%                 'BlockType', 'Goto', 'TagVisibility', 'scoped');
%             scopedGotos = [scopedGotos; find_system(RootSystemName, ...
%                 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
%                 'BlockType', 'Goto', 'TagVisibility', 'global')];
            
            scopedFroms = find_system(object.RootSystemName, ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'BlockType', 'From');
            
            scopedTags = find_system(object.RootSystemName, ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'BlockType', 'GotoTagVisibility');
            
            reads = find_system(object.RootSystemName, ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'BlockType', 'DataStoreRead');
            
            writes = find_system(object.RootSystemName, ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'BlockType', 'DataStoreWrite');
            
            mems = find_system(object.RootSystemName, ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'BlockType', 'DataStoreMemory');
            
            object.implicitMaps = struct(...
                'v2gf', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
                'gf2v', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
                'g2f', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
                'f2g', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
                'm2rw', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
                'rw2m', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
                'w2r', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
                'r2w', containers.Map('KeyType', 'char', 'ValueType', 'any'));
            
            if verbose
                disp('Step 2/7: Generating mapping from Gotos to other blocks.')
            end
            for i = coreNum:cpool:length(scopedGotos)
                b = scopedGotos{i};
                object.implicitMaps.g2f(b) = findFromsInScopeRCR(object, b, object.gtvFlag);
                object.implicitMaps.gf2v(b) = findVisibilityTagRCR(object, b, object.gtvFlag);
                
%                 if verbose
%                     disp(['Step 2 - Done scope #: ' ,num2str(i), ' of ' ,num2str(length(scopedGotos))]);
%                 end
            end
            
            if verbose
                disp('Step 3/7: Generating mapping from Froms to other blocks.')
            end
            object.implicitMaps.f2g = flipMap(object.implicitMaps.g2f);
            for i = coreNum:cpool:length(scopedFroms)
                b = scopedFroms{i};
                object.implicitMaps.f2g(b) = findGotosInScopeRCR(object, b, object.gtvFlag);
                object.implicitMaps.gf2v(b) = findVisibilityTagRCR(object, b, object.gtvFlag);
            end
            
            if verbose
                disp('Step 4/7: Generating mapping from Goto Tag Visibilities to other blocks.')
            end
            object.implicitMaps.v2gf = flipMap(object.implicitMaps.gf2v);
%             for i = 1:length(scopedTags)
%                 b = scopedTags{i};
%                 object.implicitMaps.v2gf(b) = findGotoFromsInScopeRCR(object, b, object.gtvFlag);
%             end
            
            if verbose
                disp('Step 5/7: Generating mapping from Data Store Reads to other blocks.')
            end
            for i = coreNum:cpool:length(reads)
                b = reads{i};
                object.implicitMaps.r2w(b) = findWritesInScopeRCR(object, b, object.dsmFlag);
                object.implicitMaps.rw2m(b) = findDataStoreMemoryRCR(object, b, object.dsmFlag);
            end
            
            if verbose
                disp('Step 6/7: Generating mapping from Data Store Writes to other blocks.')
            end
            object.implicitMaps.w2r = flipMap(object.implicitMaps.r2w);
            for i = coreNum:cpool:length(writes)
                b = writes{i};
%                 object.implicitMaps.w2r(b) = findReadsInScopeRCR(object, b, object.dsmFlag);
                object.implicitMaps.rw2m(b) = findDataStoreMemoryRCR(object, b, object.dsmFlag);
            end
            
            if verbose
                disp('Step 7/7: Generating mapping from Data Store Memories to other blocks.')
            end
            object.implicitMaps.m2rw = flipMap(object.implicitMaps.rw2m);
%             for i = 1:length(mems)
%                 b = mems{i};
%                 object.implicitMaps.m2rw(b) = findReadWritesInScopeRCR(object, b, object.dsmFlag);
%             end
            
            function flip = flipMap(char2charCell)
                flip = containers.Map('KeyType', 'char', 'ValueType', 'Any');
                if ~isempty(char2charCell)
                    keys = char2charCell.keys;
                    for j = 1:length(keys)
                        key = keys{j};
                        vals = char2charCell(key);
                        for k = 1:length(vals)
                            val = vals{k};
                            if flip.isKey(val)
                                flip(val) = [flip(val), {key}];
                            else
                                flip(val) = {key};
                            end
                        end
                    end
                end
            end
        end
        
        function returnToWindow(object, initialOpenSystem)
            % RETURNTOWINDOW returns the window to the one ReachCoreach
            % was used from
            % 
            % Inputs:
            %   object  ReachCoreachObject
            %   initialOpenSystem   The initial open system
            
            if object.returnToOpenSys
                % Make initial system the active window
                if(getLength(gcbp) > 1) % If within reference model (Blockpath has vertical depth)
                    cb = convertToCell(gcbp);
                    if(length(split(cb{end},'/')) > 2) % If subsystem in model (Blockpath has horizontal depth)
                        cb(end) = {gcs}; % Reference subsystem
                    else
                        cb(end) = []; % Get path of referenced model in the context of a model hierarchy
                    end
                    bp = Simulink.BlockPath(cb); 
                    open(bp)
                else % If within top level of Blockpath
                    open_system(initialOpenSystem,'force')
                end
            end
        end
    end
    
    methods(Access = private)
        function [out] = reach(object, port, currentmodel)
            % REACH Find the next ports to call the reach from, and add all
            % objects encountered to Reached Objects.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %       port    Port handle.
            %       currentmodel    Model that function is acting in
            %
            %   Output:
            %       out     Outport exit of function.
            
            % Check if this port was already traversed
            if any(object.TraversedPorts == port)
                return
            end
            
            % Get block port belongs to
            block = get_param(port, 'parent');
            
            % Mark this port as traversed
            object.TraversedPorts(end + 1) = port;
            
            out = [];
            
            % Get line from the port, and then get the destination blocks
            line = get_param(port, 'line');
            if (line == -1)
                return
            end
            
            object.ReachedObjects(end + 1) = line; % Add line to reached object
            nextBlocks = get_param(line, 'DstBlockHandle');
            
            for i = 1:length(nextBlocks)
                if nextBlocks(i) == -1
                    continue
                end
                % Add block to list of reached objects
                object.ReachedObjects(end + 1) = nextBlocks(i);
                
                % Get blocktype for switch case
                blockType = get_param(nextBlocks(i), 'BlockType');
                
                % Handle the coreaching of various blocks differently
                switch blockType
                    case 'Goto'
                        % Handles the case where the next block is a goto.
                        % Finds all froms and adds their outgoing ports to
                        % the list of ports to traverse
                        froms = findFromsInScopeRCR(object, getfullname(nextBlocks(i)), object.gtvFlag);
                        for j = 1:length(froms)
                            object.ReachedObjects(end + 1) = get_param(froms{j}, 'handle');
                            outport = get_param(froms{j}, 'PortHandles');
                            outport = outport.Outport;
                            if ~isempty(outport)
                                object.PortsToTraverse(end + 1) = outport;
                            end
                        end
                        % Adds associated goto tag visibility block to the
                        % reach
                        tag = findVisibilityTagRCR(object, getfullname(nextBlocks(i)), object.gtvFlag);
                        if ~isempty(tag)
                            object.ReachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                        end
                        
                    case 'DataStoreWrite'
                        % Handles the case where the next block is a data store
                        % write. Finds all data store reads and adds their
                        % outgoing ports to the list of ports to traverse
                        reads = findReadsInScopeRCR(object, getfullname(nextBlocks(i)), object.dsmFlag);
                        for j = 1:length(reads)
                            object.ReachedObjects(end + 1) = get_param(reads{j}, 'Handle');
                            outport = get_param(reads{j}, 'PortHandles');
                            outport = outport.Outport;
                            object.PortsToTraverse(end + 1) = outport;
                        end
                        % Adds associated data store memory block to the
                        % reach
                        mem = findDataStoreMemoryRCR(object, getfullname(nextBlocks(i)), object.dsmFlag);
                        if ~isempty(mem)
                            object.ReachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                        end
                        
                    case 'SubSystem'
                        % Handles the case where the next block is a
                        % subsystem. Adds corresponding inports inside
                        % subsystem to reach and adds their outgoing ports
                        % to list of ports to traverse
                        isVariant = get_param(nextBlocks(i), 'variant');
                            dstPorts = get_param(line, 'DstPortHandle');
                            for j = 1:length(dstPorts)
                            if get_param(get_param(dstPorts(j), 'Parent'), 'Handle') == nextBlocks(i)
                                portNum = get_param(dstPorts(j), 'PortNumber');
                                portType = get_param(dstPorts(j), 'PortType');
                                % This if statement checks for trigger, enable,
                                % or ifaction ports
                                if strcmp(portType, 'trigger')
                                    object.reachEverythingInSub(getfullname(nextBlocks(i)));
                                    triggerBlocks = find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
                                        'FollowLinks', 'on', 'BlockType', 'TriggerPort');
                                    object.ReachedObjects(end + 1) = triggerBlocks;
                                elseif strcmp(portType, 'enable')
                                    object.reachEverythingInSub(getfullname(nextBlocks(i)));
                                    enableBlocks = find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
                                        'FollowLinks', 'on', 'BlockType', 'EnablePort');
                                    object.ReachedObjects(end + 1) = enableBlocks;
                                elseif strcmp(portType, 'ifaction')
                                    object.reachEverythingInSub(getfullname(nextBlocks(i)));
                                    actionBlocks = find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
                                        'FollowLinks', 'on', 'BlockType', 'ActionPort');
                                    object.ReachedObjects(end + 1) = actionBlocks;
                                else
                                    if strcmp(isVariant, 'on')
                                        % Variant subsytem case
                                    inport = find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                        'BlockType', 'Inport', 'Port', num2str(portNum));
                                    if ~isempty(inport)
                                        object.ReachedObjects(end + 1) = get_param(inport, 'Handle');
                                        inportNum = get_param(inport, 'Port');
                                        subsystemVariants = find_system(nextBlocks(i), 'SearchDepth', 1, 'BlockType', 'SubSystem');
                                            % 1st element is of top-level variant subsystem, already in ReachedObjects
                                        for k = 2:length(subsystemVariants)
                                                variantInport = find_system(subsystemVariants(k), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                                    'BlockType', 'Inport', 'Port', inportNum);
                                                for x = 1:length(variantInport)
                                                    object.ReachedObjects(end + 1) = get_param(variantInport(x), 'Handle');
                                                    outport = get_param(variantInport(x), 'PortHandles');
                                                    outport = outport.Outport;
                                                    object.PortsToTraverse(end + 1) = outport;
                                                end
                                            end
                                        end
                                    else
                                        % Standard subsystem case
                                        inport = find_system(nextBlocks(i), 'regexp','on', 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                            'BlockType', 'Inport|InportShadow', 'Port', num2str(portNum));
                                        if ~isempty(inport)
                                            for k = 1:length(inport)
                                                object.ReachedObjects(end + 1) = get_param(inport(k), 'Handle');
                                                outport = get_param(inport(k), 'PortHandles');
                                            outport = outport.Outport;
                                            object.PortsToTraverse(end + 1) = outport;
                                        end
                                    end
                                end
                            end
                            end
                        end
                        
                    case 'ModelReference'
                        % Handles the case where the next block is a
                        % mdoel reference. Finds the corresponding inports
                        % and starts a recursive reach process within the
                        % model reference
                            dstPorts = get_param(line, 'DstPortHandle');
                            for j = 1:length(dstPorts)
                                if get_param(get_param(dstPorts(j), 'Parent'), 'Handle') == nextBlocks(i)
                                    portNum = get_param(dstPorts(j), 'PortNumber');
                                [tmpModels,tmpRefName] = find_mdlrefs(nextBlocks(i),'ReturnTopModelAsLastElement', 0);
                                load_system(tmpModels); % Load system
                                if ~any(cellfun(@isequal, object.ReachCoreachModels, repmat({tmpModels}, size(object.ReachCoreachModels))))
                                    object.ReachCoreachModels{end+1} = tmpModels{1};
                                        end
                                inport = find_system(tmpModels{1}, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                            'BlockType', 'Inport', 'Port', num2str(portNum));
                                        if ~isempty(inport)
                                    for k = 1:length(inport)
                                        object.ReachedObjects(end + 1) = get_param(inport{k}, 'Handle');
                                        outport = get_param(inport{k}, 'PortHandles');
                                            outport = outport.Outport;
                                        enterReachModelReference(object, outport, tmpRefName, tmpModels); % Start recursive call
                                    end
                                end
                            end
                        end
                        
                    case 'Outport'
                        % Handles the case where the next block is an
                        % outport. Provided the outport isn't at top level,
                        % add subsystem outport belongs to to the reach and
                        % add corresponding subsystem port of the outport to
                        % list of ports to traverse
                        
                        portNum = get_param(nextBlocks(i), 'Port');
                        parent = get_param(nextBlocks(i), 'parent');
                        grandParent = get_param(parent, 'parent');
                        if ~strcmp(grandParent, '') && ~strcmp(grandParent, currentmodel)
                            isVariant = get_param(grandParent, 'Variant');
                        else
                            isVariant = 'off';
                        end
                        if strcmp(isVariant, 'on')
                            % Variant subsystem case
                            object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                            nextOutport = find_system(grandParent, 'SearchDepth', 1, 'BlockType', 'Outport', 'Port', portNum);
                            object.ReachedObjects(end + 1) = get_param(nextOutport{1}, 'handle');
                            portSub = find_system(get_param(grandParent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', grandParent, 'PortType', 'outport', 'PortNumber', str2double(portNum));
                            object.ReachedObjects(end + 1) = get_param(grandParent, 'handle');
                            object.PortsToTraverse(end + 1) = portSub;
                        else
                            if ~isempty(get_param(parent, 'parent'))
                                portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                        'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2double(portNum));
                                bus_elements = get_param(nextBlocks(i),'Element'); % Get bus elements if they exist
                                if ~isempty(bus_elements) % If the bus elements aren't empty, then using Out Bus elements
                                    % Bus traversal case
                                    % Parse bus signal
                                    tmpsignal = split(string(bus_elements),'.');
                                    if length(tmpsignal) <= 1
                                        % Single level bus
                                        signalName = tmpsignal;
                                    else
                                        % Multi level buses
                                        signalName = cell(1,length(tmpsignal));
                                        signalName{1} = tmpsignal{end};
                                        for j = 2:length(tmpsignal)
                                            signalName{j} = strcat(tmpsignal{end-j+1},'.',signalName{j-1});
                                        end
                                    end
                                    % Start bus traversal
                                    [path, exit] = object.traverseBusForwardsHandler(block, portSub, signalName, currentmodel);
                                    object.TraversedPorts = [object.TraversedPorts path];
                                    blockList = object.busCreatorBlockMap;
                                    blockList = blockList(block);
                                    object.ReachedObjects = [object.ReachedObjects blockList];
                                    object.PortsToTraverse = [object.PortsToTraverse exit];
                                    % empty buffers
                                    remove(object.busCreatorBlockMap, block);
%                                     remove(object.busSelectorExitMap, block);
                                else
                                    % Standard case
                                object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                                object.PortsToTraverse(end + 1) = portSub;
                            end
                            else
                                out = nextBlocks(i);
                            end
                        end
                        
                    case {'WhileIterator', 'ForIterator'}
                        % Get all blocks/ports in the subsystem, then reach
                        % the blocks the outports, gotos, and writes connect
                        % to outside of the system.
                        parent = get_param(block, 'parent');
                        object.reachEverythingInSub(parent);
                        
                    case 'BusCreator'
                        % Handles the case where the next block is a bus
                        % creator. Follows the signal going into bus creator
                        % and highlights the path through the bused signal
                        % and out to its next block once the bus is
                        % separated.
                        
                        dstPort = get_param(line, 'DstPortHandle');
                        busSignals = getBusCreatorSignals(nextBlocks(i));
                        for j = 1:length(dstPort)
%                             signalName = getSignalName(line);
%                             if isempty(signalName)
%                                 portNum = get_param(dstPort(j), 'PortNumber');
%                                 signalName = ['signal' num2str(portNum)];
%                             end
                            if strcmp(get_param(get_param(dstPort(j), 'parent'), 'BlockType'), 'BusCreator')
                                portNum = get_param(dstPort(j), 'PortNumber');
                                signalName = busSignals(portNum);
                                busPort = get_param(nextBlocks(i), 'PortHandles');
                                busPort = busPort.Outport;
                                % Reach bus traversal
                                [path, exit] = object.traverseBusForwardsHandler(block, busPort, signalName, currentmodel);
                                object.TraversedPorts = [object.TraversedPorts path];
                                blockList = object.busCreatorBlockMap;
                                blockList = blockList(block);
                                object.ReachedObjects = [object.ReachedObjects blockList];
                                object.PortsToTraverse = [object.PortsToTraverse exit];
                                % empty buffers
                                remove(object.busCreatorBlockMap, block);
%                                 remove(object.busSelectorExitMap, block);
                            end
                        end
                        
                    case 'BusAssignment'
                        % Handles the case where the next block is a bus
                        % Assignment. Bus assignement are a special kind of
                        % bus creators that blend bus and non bus signals
                        assignedSignals = get_param(nextBlocks(i), 'AssignedSignals');
                        assignedSignals = regexp(assignedSignals, ',', 'split');
                        dstPorts = get_param(line, 'DstPortHandle');
                        blockInports = get_param(nextBlocks(i), 'PortHandles');
                        busPort = blockInports.Outport;
                        blockInports = blockInports.Inport;
                        inter = intersect(blockInports, dstPorts);
                        portNumbers = get_param(inter, 'PortNumber');
                        for j = 1:length(portNumbers)
                            if (portNumbers(j) ~= 1)
                                % For each port, iterate reaching through nested
                                % buses
                                if iscell(portNumbers)
                                    signalToReach = assignedSignals{portNumbers{j} - 1};
                                else
                                    signalToReach = assignedSignals{portNumbers(j) - 1};
                                end
                                flag = true;
                                while flag
                                    % Traverse bus
                                    [path, exit] = object.traverseBusForwardsHandler(block, busPort, signalToReach, currentmodel);
                                    object.TraversedPorts = [object.TraversedPorts path];
                                    blockList = object.busCreatorBlockMap;
                                    blockList = blockList(block);
                                    object.ReachedObjects = [object.ReachedObjects blockList];
                                    % empty buffers
                                    remove(object.busCreatorBlockMap, block);
%                                     remove(object.busSelectorExitMap, block);
                                    dots = strfind(signalToReach, '.');
                                    if isempty(dots)
                                        flag = false;
                                    else
                                        signalToReach = signalToReach(1:dots(end)-1);
                                    end
                                    busPort = exit;
                                end
                            else
                                ports = get_param(nextBlocks(i), 'PortHandles');
                                outports = ports.Outport;
                                for k = 1:length(outports)
                                    object.PortsToTraverse(end + 1) = outports(k);
                                end
                                exit = [];
                            end
                            object.PortsToTraverse = [object.PortsToTraverse exit];
                        end
                        
                    case 'If'
                        % Handles the case where the next block is an if
                        % block. Reaches each port where the corresponding
                        % condition is referenced and the else port
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        outports = ports.Outport;
                        dstPort = get_param(line, 'DstPortHandle');
                        for j = 1:length(dstPort)
                            if strcmp(get_param(get_param(dstPort(i),'parent'), 'BlockType'), 'If')
                                portNum = get_param(dstPort(i), 'PortNumber');
                                cond = ['u' num2str(portNum)];
                                expressions = get_param(nextBlocks(i), 'ElseIfExpressions');
                                if ~isempty(expressions)
                                    expressions = regexp(expressions, ',', 'split');
                                    expressions = [{get_param(nextBlocks(i), 'IfExpression')} expressions];
                                else
                                    expressions = {};
                                    expressions{end + 1} = get_param(nextBlocks(i), 'IfExpression');
                                end
                                elseFlag = false;
                                for k = 1:length(expressions)
                                    if regexp(expressions{k}, cond)
                                        elseFlag = true;
                                        for m = 1:length(expressions)+1-k
                                            object.PortsToTraverse(end + 1) = outports(m+k-1);
                                        end
                                    end
                                end
                                if strcmp(get_param(nextBlocks(i), 'ShowElse'), 'on')
                                    if elseFlag
                                        object.PortsToTraverse(end + 1) = outports(end);
                                    end
                                end
                            end
                        end
                        
                    case 'FunctionCaller'
                        % Find the Simulink Function and trace it.
                        % Add any outports that the Simulink Function may have to
                        % the list of items to traverse.
                        
                        % Add the corresponding Simulink Function to reached list
                        fcn = matchSimFcn(nextBlocks(i));
                        if iscell(fcn) && length(fcn) > 1 % Should only be 1, but just in case, we check
                            fcn = fcn{1};
                        end
                        object.ReachedObjects(end + 1) = get_param(fcn, 'handle');
                        
                        % Add the Simulink Function's contained blocks and lines
                        containedBlocks = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                        for j = 1:length(containedBlocks)
                            object.ReachedObjects(end + 1) = get_param(containedBlocks{j}, 'handle');
                        end
                        
                        containedLines = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
                        object.ReachedObjects = [object.ReachedObjects containedLines.'];

                        % Add the Simulink Function's outports to the list
                        ports = get_param(fcn, 'PortHandles');
                        outport = ports.Outport;
                        if ~isempty(outport)
                            object.PortsToTraverse = [object.PortsToTraverse outport];
                        end
                         
                        % Add the outports for the Caller itself
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        outports = ports.Outport;
                        for j = 1:length(outports)
                            object.PortsToTraverse(end + 1) = outports(j);
                        end

                    otherwise
                        % Otherwise case, simply adds outports of block to
                        % the list of ports to traverse
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        outports = ports.Outport;
                        for j = 1:length(outports)
                            object.PortsToTraverse(end + 1) = outports(j);
                        end
                end
            end
        end
        
        function [in] = coreach(object, port, currentmodel)
            % COREACH Find the next ports to find the coreach from, and add all
            % objects encountered to coreached objects.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %       port    Port handle.
            %       currentmodel    Model that function is acting in
            %
            %   Outputs:
            %       in      Inport exit of function
            
            in = [];
            
            % Check if this port was already traversed
            if any(object.TraversedPortsCo == port)
                return
            end
            
            % Mark this port as traversed
            object.TraversedPortsCo(end + 1) = port;
            
            % Get the line from the port, and then get the destination blocks
            line = get_param(port, 'line');
            if (line == -1)
                return
            end
            
            object.CoreachedObjects(end + 1) = line; % Add line to coreached objects
            nextBlocks = get_param(line, 'SrcBlockHandle');
            
            
            for i = 1:length(nextBlocks)
                if (nextBlocks(i) == -1)
                    break
                end
                % Add the block to list of coreached objects
                object.CoreachedObjects(end + 1) = nextBlocks(i);
                
                % Get blocktype for switch case
                blockType = get_param(nextBlocks(i), 'BlockType');
                
                % Handle the coreaching of various blocks differently
                switch blockType
                    case 'From'
                        % Handles the case where the next block is a from
                        % block. Finds all gotos associated with the from
                        % block, adds them to the coreach blocks, then adds
                        % their respective inports to the list of ports to
                        % traverse
                        gotos = findGotosInScopeRCR(object, getfullname(nextBlocks(i)), object.gtvFlag);
                        for j = 1:length(gotos)
                            object.CoreachedObjects(end + 1) = get_param(gotos{j}, 'handle');
                            inport = get_param(gotos{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        % Adds the associated goto tag visibility block to
                        % the list of coreached objects
                        tag = findVisibilityTagRCR(object, getfullname(nextBlocks(i)), object.gtvFlag);
                        if ~isempty(tag)
                            object.CoreachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                        end
                        
                    case 'DataStoreRead'
                        % Handles the case where the next block is a data
                        % store read block. Finds all gotos associated with
                        % the write block, adds them to the coreached
                        % blocks, then adds their respective inports to the
                        % list of ports to traverse
                        writes = findWritesInScopeRCR(object, getfullname(nextBlocks(i)), object.dsmFlag);
                        for j = 1:length(writes)
                            object.CoreachedObjects(end + 1) = get_param(writes{j}, 'Handle');
                            inport = get_param(writes{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        % Adds the associated data store memory block to
                        % the list of coreached objects
                        mem = findDataStoreMemoryRCR(object, getfullname(nextBlocks(i)), object.dsmFlag);
                        if ~isempty(mem)
                            object.CoreachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                        end
                        
                    case 'SubSystem'
                        % Handles the case where the next block is a
                        % subsystem. Finds outport block corresponding to
                        % the outport of the subsystem, adds it to the
                        % list of coreached objects, then adds its inport to
                        % the list of inports to traverse
                        srcPorts = get_param(line, 'SrcPortHandle');
                        isVariant = get_param(nextBlocks(i), 'Variant');
                        if strcmp(isVariant, 'on')
                            % Variant subsystem case
                            for j = 1:length(srcPorts)
                                portNum = get_param(srcPorts(j), 'PortNumber');
                                outport = find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                    'BlockType', 'Outport', 'Port', num2str(portNum));
                                if ~isempty(outport)
                                    object.CoreachedObjects(end + 1) = get_param(outport, 'Handle');
                                    outportNum = get_param(outport, 'Port');
                                    subsystemVariants = find_system(nextBlocks(i), 'SearchDepth', 1, 'BlockType', 'SubSystem');
                                    % 1st element is of top-level variant subsystem, already in CoreachedObjects
                                    for k = 2:length(subsystemVariants)
                                        variantInport = find_system(subsystemVariants(k), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                                    'BlockType', 'Outport', 'Port', outportNum);
                                        for x = 1:length(variantInport)
                                            object.CoreachedObjects(end + 1) = get_param(variantInport(x), 'Handle');
                                            inport = get_param(variantInport(x), 'PortHandles');
                                        inport = inport.Inport;
                                        object.PortsToTraverseCo(end + 1) = inport;
                                    end
                                end
                            end
                            end
                        else
                            % Standard case
                            for j = 1:length(srcPorts)
                                portNum = get_param(srcPorts(j), 'PortNumber');
                                outport = find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                                if ~isempty(outport)
                                    for k = 1:length(outport)
                                        object.CoreachedObjects(end + 1) = get_param(outport(k), 'Handle');
                                        inport = get_param(outport(k), 'PortHandles');
                                    inport = inport.Inport;
                                    object.PortsToTraverseCo(end + 1) = inport;
                                end
                            end
                        end
                        end
                        
                    case 'ModelReference'
                        % Handles the case where the next block is a model
                        % reference block. Finds the ecit port of the model
                        % reference block and starts recursive coreach from
                        % the port
                        srcPorts = get_param(line, 'SrcPortHandle');
                        for j = 1:length(srcPorts)
                            portNum = get_param(srcPorts(j), 'PortNumber');
                            [tmpModels,tmpRefName] = find_mdlrefs(nextBlocks(i),'ReturnTopModelAsLastElement', 0);
                            load_system(tmpModels);
                            if ~any(cellfun(@isequal, object.ReachCoreachModels, repmat({tmpModels}, size(object.ReachCoreachModels))))
                                object.ReachCoreachModels{end+1} = tmpModels{1};
                            end
                            outport = find_system(tmpModels{1}, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                'BlockType', 'Outport', 'Port', num2str(portNum));
                            if ~isempty(outport)
                                for k = 1:length(outport)
                                    object.CoreachedObjects(end + 1) = get_param(outport{k}, 'Handle');
                                    inport = get_param(outport{k}, 'PortHandles');
                                    inport = inport.Inport;
                                    enterCoReachModelReference(object, inport, tmpRefName, tmpModels); % Recursive coreach call
                                end    
                            end
                        end
                        
                    case 'Inport'
                        % Handles the case where the next block is an
                        % inport. If the inport is not top level, it adds
                        % the parent subsystem to the list of coreached
                        % objects, then adds the corresponding inport on the
                        % subsystem to the list of ports to traverse
                        portNum = get_param(nextBlocks(i), 'Port');
                        parent = get_param(nextBlocks(i), 'parent');
                        grandParent = get_param(parent, 'parent');
                        if ~strcmp(grandParent, '') && ~strcmp(grandParent, currentmodel)
                            isVariant = get_param(grandParent, 'Variant');
                        else
                            isVariant = 'off';
                        end
                        if strcmp(isVariant, 'on')
                            % Variant subsystem case
                            object.CoreachedObjects(end + 1) = get_param(parent, 'handle');
                            nextInport = find_system(grandParent, 'SearchDepth', 1, 'BlockType', 'Inport', 'Port', portNum);

                            object.CoreachedObjects(end + 1) = get_param(nextInport{1}, 'handle');
                            portSub = find_system(get_param(grandParent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', grandParent, 'PortType', 'inport', 'PortNumber', str2double(portNum));
                            object.CoreachedObjects(end + 1) = get_param(grandParent, 'handle');
                            object.PortsToTraverseCo(end + 1) = portSub;
                        else
                            if ~isempty(get_param(parent, 'parent'))
                                portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                        'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2double(portNum));
                                bus_elements = get_param(nextBlocks(i),'Element'); % Get bus elements if they exist
                                if ~isempty(bus_elements) % If the bus elements aren't empty, then using Out Bus elements
                                    % Bus traversal case
                                    % Parse 
                                    tmpsignal = split(string(bus_elements),'.');
                                    if length(tmpsignal) <= 1
                                        signalName = tmpsignal;
                                    else
                                        % Handles multi level buses
                                        signalName = cell(1,length(tmpsignal));
                                        signalName{1} = tmpsignal{end};
                                        for j = 2:length(tmpsignal)
                                            signalName{j} = tmpsignal{end-j+1};
                                        end
                                    end
                                    [path, blockList, exit] = object.traverseBusBackwardsHandler(portSub, signalName, currentmodel);
                                    object.TraversedPortsCo = [object.TraversedPortsCo path];
                                    object.CoreachedObjects = [object.CoreachedObjects blockList];
                                    object.PortsToTraverseCo = [object.PortsToTraverseCo exit];
                                else
                                    % Standard case
                                object.CoreachedObjects(end + 1) = get_param(parent, 'handle');
                                object.PortsToTraverseCo(end + 1) = portSub;
                            end
                            else
                                in = nextBlocks(i);
                            end
                        end
                        
                    case 'BusSelector'
                        % Handles the case where the next block is a bus
                        % selector. Follows the signal going into the bus
                        % and adds the path through the bus to the list of
                        % coreached objects. Adds the corresponding exit
                        % port on the bus creator to the list of ports to
                        % traverse
                        busPort= get_param(nextBlocks(i), 'PortHandles');
                        signal = get_param(nextBlocks(i), 'OutputSignals');
                        signal = regexp(signal, ',', 'split');
                        if length(busPort.Outport) ~= 1
                            % Bus Selector is NOT configured with virtual bus
                            % output - select correct outport
                        portBus = get_param(line, 'SrcPortHandle');
                        portNum = get_param(portBus, 'PortNumber');
                            signal = {signal{portNum}};
                        end
                        for j = 1:length(signal)
                            [path, blockList, exit] = object.traverseBusBackwardsHandler(busPort.Inport, {signal{j}}, currentmodel);
                        object.TraversedPortsCo = [object.TraversedPortsCo path];
                        object.CoreachedObjects = [object.CoreachedObjects blockList];
                        object.PortsToTraverseCo = [object.PortsToTraverseCo exit];
                        end
                        
                    case 'If'
                        % Handles the case where the next block is an if
                        % block. Adds ports with conditions corresponding to
                        % the conditions associated with teh outport the
                        % current port leads into to the list of ports to
                        % traverse
                        srcPort = get_param(line, 'SrcPortHandle');
                        portNum = get_param(srcPort, 'PortNumber');
                        expressions = get_param(nextBlocks(i), 'ElseIfExpressions');
                        if ~isempty(expressions)
                            expressions = regexp(expressions, ', *', 'split');
                            expressions = [{get_param(nextBlocks(i), 'IfExpression')} expressions];
                        else
                            expressions = {};
                            expressions{end + 1} = get_param(nextBlocks(i), 'IfExpression');
                        end
                        if portNum > length(expressions)
                            % Else case
                            limit = portNum - 1;
                        else
                            limit = portNum;
                        end
                        ifPorts = get_param(nextBlocks(i), 'PortHandles');
                        ifPorts = ifPorts.Inport;
                        condsToCoreach = zeros(1, length(ifPorts));
                        for j = 1:limit
                            conds = regexp(expressions{j}, 'u[1-9][0-9]*', 'match');
                            for k = 1:length(conds)
                                c = conds{k};
                                condsToCoreach(str2num(c(2:end))) = 1;
                            end

                        end
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ifPorts(logical(condsToCoreach))];
%                         else
%                             conditions = regexp(expressions{portNum}, 'u[1-9][0-9]*', 'match');
%                             for j = 1:length(conditions)
%                                 cond = conditions{j};
%                                 cond = cond(2:end);
%                                 ifPorts = get_param(nextBlocks(i), 'PortHandles');
%                                 ifPorts = ifPorts.Inport;
%                                 object.PortsToTraverseCo(end + 1) = ifPorts(str2num(cond));
%                             end
%                         end

                    case 'ForIterator'
                        toCoreach = getInterfaceOut(object, get_param(nextBlocks(i), 'parent'));
                        for j = 1:length(toCoreach)
                            ports = get_param(toCoreach{j}, 'PortHandles');
                            object.CoreachedObjects(end+1) = get_param(toCoreach{j}, 'Handle');
                            inports = ports.Inport;
                            for k = 1:length(inports)
                                object.PortsToTraverseCo(end + 1) = inports(k);
                            end
                        end
                        ins = find_system(get_param(nextBlocks(i), 'parent'), 'SearchDepth', 1, 'BlockType', 'Outport');
                        for j = 1:length(ins)
                            ports = get_param(ins{j}, 'PortHandles');
                            object.CoreachedObjects(end+1) = get_param(ins{j}, 'Handle');
                            inports = ports.Inport;
                            for k = 1:length(inports)
                                object.PortsToTraverseCo(end + 1) = inports(k);
                            end
                        end
                        
                    case 'FunctionCaller'
                        % Find the Simulink Function and trace it.
                        % Add any inports that the Simulink Function may have to
                        % the list of items to traverse.
                        
                        % Add the corresponding Simulink Function to reached list
                        fcn = matchSimFcn(nextBlocks(i));
                        if iscell(fcn) && length(fcn) > 1 % Should only be 1, but just in case, we check
                            fcn = fcn{1};
                        end
                        object.CoreachedObjects(end + 1) = get_param(fcn, 'handle');
                        
                        % Add the Simulink Function's contained blocks and lines
                        containedBlocks = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                        for j = 1:length(containedBlocks)
                            object.CoreachedObjects(end + 1) = get_param(containedBlocks{j}, 'handle');
                        end
                        
                        containedLines = find_system(fcn, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
                        object.CoreachedObjects = [object.CoreachedObjects containedLines.'];

                        % Add the Simulink Function's outports to the list
                        ports = get_param(fcn, 'PortHandles');
                        inport = ports.Inport;
                        if ~isempty(inport)
                            object.PortsToTraverseCo = [object.PortsToTraverseCo inport];
                        end
                         
                        % Add the outports for the Caller itself
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        inports = ports.Inport;
                        for j = 1:length(inports)
                            object.PortsToTraverseCo(end + 1) = inports(j);
                        end
                        
                    otherwise
                        % Otherwise case, simply adds the inports of the block
                        % to the list of ports to traverse.
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        inports = ports.Inport;
                        for j = 1:length(inports)
                            object.PortsToTraverseCo(end + 1) = inports(j);
                        end
                end
            end
        end
        
        function iterators = findIterators(object)
            % FINDITERATORS Find all while and for iterators that need to be
            % coreached.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %       port
            %
            %   Outputs:
            %       N/A
            
            iterators = {};
            candidates = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'WhileIterator');
            tmp = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ForIterator');
            
            if iscolumn(candidates)
                candidates = candidates';
            end
            if iscolumn(tmp)
                tmp = tmp';
            end
            
            candidates = [candidates tmp];
            for i = 1:length(candidates)
                system = get_param(candidates{i}, 'parent');
                sysObjects = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects = setdiff(sysObjects, system);
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(candidates{i}, 'Handle'), object.CoreachedObjects))
                        iterators{end + 1} = candidates{i};
                    end
                end
            end
        end
        
        function findSpecialPorts(object)
            % FINDSPECIALPORTS Find all actionport, foreach, triggerport, and
            % enableport blocks and adds them to the coreach, as well as adding
            % their corresponding port in the parent subsystem block to the list
            % of ports to traverse.
            %
            %   Input:
            %       object  ReachCoreach object.
            %
            %   Outputs:
            %       N/A
            
            forEach = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ForEach');
            triggerPorts = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'TriggerPort');
            actionPorts = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ActionPort');
            enablePorts = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'EnablePort');
            excludeBlocks = [forEach; triggerPorts; actionPorts; enablePorts];
            toExclude=[];
            for i = 1:length(excludeBlocks)
                toExclude(end + 1) = get_param(excludeBlocks{i}, 'handle');
            end
            
            for i = 1:length(actionPorts)
                system = get_param(actionPorts{i}, 'parent');
                sysObjects = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects = setdiff(sysObjects, get_param(system, 'handle'));
                sysObjects = setdiff(sysObjects, toExclude);
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(actionPorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(actionPorts{i}, 'Handle');
                        sysPorts = get_param(system, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo sysPorts.Ifaction];
                    end
                end
            end
            
            for i = 1:length(triggerPorts)
                system = get_param(triggerPorts{i}, 'parent');
                sysObjects = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects = setdiff(sysObjects, get_param(system, 'handle'));
                sysObjects = setdiff(sysObjects, toExclude);
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(triggerPorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(triggerPorts{i}, 'Handle');
                        sysPorts = get_param(system, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo sysPorts.Trigger];
                    end
                end
            end
            
            for i = 1:length(enablePorts)
                system = get_param(enablePorts{i}, 'parent');
                sysObjects = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects = setdiff(sysObjects, get_param(system, 'handle'));
                sysObjects = setdiff(sysObjects, toExclude);
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(enablePorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(enablePorts{i}, 'Handle');
                        sysPorts = get_param(system, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo sysPorts.Enable];
                    end
                end
            end
            
            for i = 1:length(forEach)
                system = get_param(forEach{i}, 'parent');
                sysObjects = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects = setdiff(sysObjects, get_param(system, 'handle'));
                sysObjects = setdiff(sysObjects, toExclude);
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(forEach{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(forEach{i}, 'Handle');
                    end
                end
            end
        end
        
        function reachEverythingInSub(object, system)
            % REACHEVERYTHINGINSUB Add all blocks and outports of blocks in the
            % subsystem to the lists of reached objects. Also find all interface
            % going outward (outports, gotos, froms) and find the next
            % blocks/ports as if being reached by the main reach function.
            %
            %   Inputs:
            %       object ReachCoreach object.
            %       system
            %
            %   Outputs:
            %       N/A
            
            blocks = find_system(system, 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'block');
            
            % Excludes trigger, enable, and action port blocks (they are
            % added in main function)
            blocksToExclude = find_system(system, 'FindAll', 'on', 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'block', 'BlockType', 'EnablePort');
            blocksToExclude = [blocksToExclude; find_system(system, 'FindAll', 'on', 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'block', 'BlockType', 'TriggerPort')];
            blocksToExclude = [blocksToExclude; find_system(system, 'FindAll', 'on', 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'block', 'BlockType', 'ActionPort')];
            blocks = setdiff(blocks, blocksToExclude);
            
            if iscolumn(blocks)
                object.ReachedObjects = [object.ReachedObjects, blocks'];
            else
                object.ReachedObjects = [object.ReachedObjects, blocks];
            end
            
            lines = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
            object.ReachedObjects = [object.ReachedObjects lines.'];
            ports = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'port');
            if iscolumn(ports)
                ports = ports.';
            end
            portsToExclude = get_param(system, 'PortHandles');
            portsToExclude = portsToExclude.Outport;
            ports = setdiff(ports, portsToExclude);
            object.TraversedPorts = [object.TraversedPorts ports];
            
            % Handles outports the same as the reach function
            outports = find_system(system, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport');
            for j = 1:length(outports)
                portNum = get_param(outports{j}, 'Port');
                parent = get_param(outports{j}, 'parent');
                if ~isempty(get_param(parent, 'parent'))
                    port = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                        'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2double(portNum));
                    object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                    object.PortsToTraverse(end + 1) = port;
                end
            end
            
            % Handles gotos the same as the reach function
            gotos = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto');
            gotosToIgnore = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto', 'TagVisibility', 'local');
            gotos = setdiff(gotos, gotosToIgnore);
            for j = 1:length(gotos)
                froms = findFromsInScopeRCR(object, gotos{j}, object.gtvFlag);
                for k = 1:length(froms)
                    object.ReachedObjects(end + 1) = get_param(froms{k}, 'handle');
                    outport = get_param(froms{k}, 'PortHandles');
                    outport = outport.Outport;
                    object.PortsToTraverse(end + 1) = outport;
                end
                tag = findVisibilityTagRCR(object, gotos{j}, object.gtvFlag);
                if ~isempty(tag)
%                     if iscell(tag)
%                         tag=tag{1};
%                     end
                    object.ReachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                end
            end
            
            % Handles writes the same as the reach function
            writes = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite');
            for j = 1:length(writes)
                reads = findReadsInScopeRCR(object, writes{j}, object.dsmFlag);
                for k = 1:length(reads)
                    object.ReachedObjects(end + 1) = get_param(reads{k}, 'Handle');
                    outport = get_param(reads{k}, 'PortHandles');
                    outport = outport.Outport;
                    object.PortsToTraverse(end + 1) = outport;
                end
                mem = findDataStoreMemoryRCR(object, writes{j}, object.dsmFlag);
                if ~isempty(mem)
%                     if iscell(mem)
%                         mem=mem{1};
%                     end
                    object.ReachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                end
            end
            
            %object.PortsToTraverse = setdiff(object.PortsToTraverse, object.TraversedPorts);
        end
        
        function blocks = getInterfaceIn(object, subsystem)
            % GETINTERFACEIN Get all the source blocks for the subsystem,
            % including Gotos and Data Store Writes.
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       subsystem
            %
            %   Outputs:
            %       blocks
            
            blocks = {};
            gotos = {};
            writes = {};
            froms = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'From');
            allTags = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'GotoTagVisibility');
            for i = 1:length(froms)
                gotos = [gotos; findGotosInScopeRCR(object, froms{i}, object.gtvFlag)];
                tag = findVisibilityTagRCR(object, froms{i}, object.gtvFlag);
                tag = setdiff(tag, allTags);
                if ~isempty(tag)
%                     if iscell(tag)
%                         tag = tag{1};
%                     end
                    object.CoreachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                end
            end
            gotos = setdiff(gotos, find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto'));
            
            reads = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreRead');
            allMems = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreMemory');
            for i = 1:length(reads)
                writes = [writes; findWritesInScopeRCR(object, reads{i}, object.dsmFlag)];
                mem = findDataStoreMemoryRCR(object, reads{i}, object.dsmFlag);
                mem = setdiff(mem, allMems);
                if ~isempty(mem)
%                     if iscell(mem)
%                         mem = mem{1};
%                     end
                    object.CoreachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                end
            end
            writes = setdiff(writes, find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite'));
            
            implicits = [gotos writes];
            for i = 1:length(implicits)
                name = getfullname(implicits{i});
                lcs = intersect(name, getfullname(subsystem));
                if ~strcmp(lcs, getfullname(subsystem))
                    blocks{end + 1} = implicits{i};
                end
            end
        end
        
        function blocks = getInterfaceOut(object, subsystem)
            % GETINTERFACEOUT Get all the destination blocks for the subsystem,
            % including Froms and Data Store Reads.
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       subsystem   
            %
            %   Output:
            %       blocks
            
            blocks = {};
            froms = {};
            reads = {};
            gotos = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto');
            allTags = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'GotoTagVisibility');
            for i = 1:length(gotos)
                if ~strcmp(get_param(gotos{i}, 'TagVisibility'), 'local')
                    froms = [froms; findFromsInScopeRCR(object, gotos{i}, object.gtvFlag)];
                    tag = findVisibilityTagRCR(object, gotos{i}, object.gtvFlag);
                    tag = setdiff(tag, allTags);
                    if ~isempty(tag)
%                         if iscell(tag)
%                             tag = tag{1};
%                         end
                        object.ReachedObjects(end + 1) = get_param(tag{1}, 'Handle');
                    end
                end
            end
            froms = setdiff(froms, find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'From'));
            
            writes = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite');
            allMems = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreMemory');
            for i = 1:length(writes)
                reads = [reads; findReadsInScopeRCR(object, writes{i}, object.dsmFlag)];
                mem = findDataStoreMemoryRCR(object, writes{i}, object.dsmFlag);
                mem = setdiff(mem, allMems);
                if ~isempty(mem)
%                     if iscell(mem)
%                         mem=mem{1};
%                     end
                    object.ReachedObjects(end + 1) = get_param(mem{1}, 'Handle');
                end
            end
            reads = setdiff(reads, find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreRead'));
            
            implicits = [froms reads];
            for i = 1:length(implicits)
                name = getfullname(implicits{i});
                lcs = intersect(name, getfullname(subsystem));
                if ~strcmp(lcs, getfullname(subsystem))
                    blocks{end + 1} = implicits{i};
                end
            end
        end
        
        function [buspath, busexit] = traverseBusForwardsHandler(object, creator, oport, signal, currentmodel)
            % TRAVERSEBUSFORWARDSHANDLER Starts reach bus process wrapper
            % Links the traverseBusForwards and reach processes
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %       creator
            %       oport
            %       signal
            %       currentmodel
            %
            %   Outputs:
            %       buspath
            %       busexit
            
            % nextports and signals are paired
            % Their varables are connected by order
            nextports = oport;
            signals = [{signal}]; % This is an array of cell arrays of cell arrays
            buspath = [];
            busexit = [];
            while ~isempty(nextports)
                oport = nextports(end);
                nextports(end) = [];
                osignal = signals(end);
                signals(end) = [];
                [buspath, exit, addsignal, addports] = object.traverseBusForwards(creator, oport, osignal, buspath, currentmodel);
                nextports = [nextports addports];
                signals = [signals addsignal];
                if ~isempty(exit)
                    busexit = [busexit exit]; % Get bus traversal exits
                end
            end
            buspath = unique(buspath);
        end
        
        function [path, exit, nextsignal, nextoport] = traverseBusForwards(object, creator, oport, signal, path, currentmodel)
            % TRAVERSEBUSFORWARDS Go until a Bus Creator is encountered. Then,
            % return the path taken there as well as the exiting port.
            %
            %   Inputs:
            %       object  ReachCoreach object.
            %       creator
            %       oport
            %       signal
            %       path
            %       currentmodel
            %
            %   Outputs:
            %       path
            %       exit
            %       nextsignal
            %       nextoport
            
            exit = [];
            nextsignal = [];
            nextoport = [];
            
            for g = 1:length(oport)
                parentBlock = get_param(get_param(oport(g), 'parent'), 'Handle');
%                 if strcmp(get_param(parentBlock, 'BlockType'), 'SFunction')
%                     % Note SFunction is not the correct spelling for an S-Function block, so that is probably an error. 
%                     object.addToMappedArray('busCreatorExitMap', creator, oport(g))
%                     break
%                 end
                
                % Stops infinite loops
                if ismember(oport(g), path)
                    continue
                end
                
                object.addToMappedArray('busCreatorBlockMap', creator, parentBlock)
                portline = get_param(oport(g), 'Line');
                
                try
                    dstBlocks = get_param(portline, 'DstBlockHandle');
                catch
                    break
                end
                
                object.addToMappedArray('busCreatorBlockMap', creator, portline)
                path(end + 1) = oport(g);
                
                % If the bus ends early (not at Bus Selector) output empty
                % exit
                if isempty(dstBlocks)
                    exit = [];
                end
                
                % For each of the destination blocks
                for h = 1:length(dstBlocks)
                    next = dstBlocks(h);
                    blockType = get_param(next, 'BlockType');
                    
                    switch blockType
                        case 'BusCreator'
                            % If the next block is a Bus Creator, call the
                            % traverse function recursively
                            signalName = get_param(portline, 'Name');
                            
                            % Get all destination ports from the signal
                            % line into the Bus Creator
                            dstPort = get_param(portline, 'DstPortHandle');
                            nextports = get_param(next, 'PortHandles');
                            inports = nextports.Inport;
                            dstPort = intersect(dstPort, inports);
                            if isempty(signalName)
                                % Umnamed signal case (defaults to signal#)
                                for i = 1:length(dstPort)
                                    portNum = get_param(dstPort(g), 'PortNumber');
                                    signalName = strcat('signal', num2str(portNum), '.', signal{1}{end});
                                    nextsignal = [nextsignal {[signal{1} signalName]}];
                                    nextoport = [nextoport nextports.Outport];
                                end
                            else
                                % Standard bus constructor case
                                signalName = strcat(signalName, '.', signal{1}{end});
                                nextsignal = [nextsignal {[signal{1} signalName]}];
                                nextoport = [nextoport nextports.Outport];
                            end
                            
                        case 'BusSelector'
                            % Base case for recursion: Get the exiting
                            % port from the Bus Selector and pass out all
                            % other relevant information
                            object.addToMappedArray('busCreatorBlockMap', creator, get_param(next , 'handle'));
                            outputs = get_param(next, 'OutputSignals');
                            outputs = regexp(outputs, ',', 'split');
                            
                            portNum = find(strcmp(outputs(:), signal{1}(end)));
                            if ~isempty(portNum)
                                % Virtual Bus (Multi-level output) case
                                temp = get_param(next, 'PortHandles');
                                temp = temp.Outport;
                                if length(temp) == 1
                                    % The bus selector is configured to
                                    % output a virtual bus - only one outport
                                    exit = [exit temp];
                                else
                                exit = [exit temp(portNum)];
                                end
                            else
                                % Standard bus selector case
                                for i = 1:length(outputs)
                                    index = strfind(string(signal{1}(end)), outputs{i});
                                    if ~isempty(index)
                                        % Signal found
                                        if index(1) == 1
                                            temp = get_param(next, 'PortHandles');
                                            temp = temp.Outport;
                                            if length(temp) == 1
                                                % virtual bus output - one outport
                                                temp = temp(1);
                                            else
                                                temp = temp(i);
                                        end
                                            if length(signal{1}) > 1
                                                nextsignal = [nextsignal {signal{1}(1:end-1)}];
                                                nextoport = [nextoport temp];
                                    else
                                                exit = [exit temp];
                                            end
                                        end
                                    end
                                end
                            end
                            
                        case 'BusToVector'
                            %goes backwards through the bus to find the
                            %port that the signal originates from in the
                            %BusCreator, then use that as the signal num
                            %for traversing the bus
                            object.addToMappedArray('busCreatorBlockMap', creator, get_param(next , 'handle'));
                            nextPorts = get_param(next, 'PortHandles');
                            nextPorts = nextPorts.Outport;
                            exit = [exit nextPorts];
                        
                        case 'Goto'
                            % Follow the bus through Goto blocks
                            object.addToMappedArray('busCreatorBlockMap', creator, get_param(next , 'handle'));
                            froms = findFromsInScopeRCR(object, next, object.gtvFlag);
                            for i = 1:length(froms)
                                outport = get_param(froms{i}, 'PortHandles');
                                outport = outport.Outport;
                                for j = 1:length(outport)
                                	nextsignal = [nextsignal signal];
                                end
                                nextoport = [nextoport outport];
                                tag = findVisibilityTagRCR(object, froms{i}, object.gtvFlag);
                                if ~isempty(tag)
                                    object.addToMappedArray('busCreatorBlockMap', creator, get_param(tag{1}, 'Handle'));
                                end
                            end
                            
                        case 'SubSystem'
                            % Follow the bus into Subsystems
                            object.addToMappedArray('busCreatorBlockMap', creator, get_param(next , 'handle'));
                            isVariant = get_param(next, 'variant');
                            dstPorts = get_param(portline, 'DstPortHandle');
                            
                            for j = 1:length(dstPorts)
                                    portNum = get_param(dstPorts(j), 'PortNumber');
                                
                                if strcmp(isVariant, 'on')
                                    % Variant subsystem case
                                    inport = find_system(next, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Inport', 'Port', num2str(portNum));
                                    object.addToMappedArray('busCreatorBlockMap', creator, get_param(inport, 'Handle'));
                                    inportNum = get_param(inport, 'Port');
                                    subsystemVariants = find_system(next, 'SearchDepth', 1, 'BlockType', 'SubSystem');
                                    % 1st element is of top-level variant subsystem, already in 
                                    for k = 2:length(subsystemVariants)
                                        variantInport = find_system(subsystemVariants(k), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Inport', 'Port', inportNum);
                                        inportPort = get_param(variantInport, 'PortHandles');
                                        if ~isempty(inportPort)
                                            if length(inportPort) <= 1
                                                outinportPort = inportPort.Outport;
                                                nextsignal = [nextsignal signal];
                                                nextoport = [nextoport outinportPort];
                                            else
                                                for m = 1:length(inportPort)
                                                    outinportPort = inportPort{m}.Outport;
                                                    nextsignal = [nextsignal signal];
                                                    nextoport = [nextoport outinportPort];
                                                end
                                            end
                                        end
                                    end
                                else
                                    if strcmp(get_param(dstPorts(j), 'parent'), getfullname(next))
                                        inport = find_system(next, 'regexp', 'on', 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                            'BlockType', 'Inport|InportShadow', 'Port', num2str(portNum));
                                        bus_elements = get_param(inport,'Element'); % Get bus elements if they exist
                                        if ~isempty(bus_elements) && any(not(cellfun('isempty',bus_elements)))% Using In Bus elements (Virtual Bus)
                                            % Bus element case
                                            tmpsig = split(string(signal{1}{end}),'.');
                                            for i = 1:length(bus_elements) % For each bus entrance into subsystem
                                                % Parse Bus signal
                                                tmpbus = split(string(bus_elements{i}),'.');
                                                goflag = true;
                                                for k = 1:length(tmpbus)
                                                    if tmpsig(k) ~= tmpbus(k)
                                                        goflag = false;
                                                        break;
                                                    end
                                                end
                                                if goflag % If port found
                                                    temp = get_param(inport, 'PortHandles');
                                                    temp = temp{i};
                                                    temp = temp.Outport;
                                                    if length(bus_elements{i}) == length(signal{1}{end}) % If exact match
                                                        object.addToMappedArray('busCreatorBlockMap', creator, inport(i));
                                                        exit = [exit temp]; % Bus exit found
                                                    else
                                                        nextsignal = [nextsignal {signal{1}(1:end-length(tmpbus))}];
                                                        nextoport = [nextoport temp];
                                                    end
                                                end
                                            end
                                        else % Standard Subsystem Inport
                                    inportPort = get_param(inport, 'PortHandles');
                                            if ~isempty(inportPort)
                                                if length(inportPort) <= 1
                                                    outinportPort = inportPort.Outport;
                                                    nextsignal = [nextsignal signal];
                                                    nextoport = [nextoport outinportPort];
                                                else
                                                    for k = 1:length(inportPort)
                                                        outinportPort = inportPort{k}.Outport;
                                                        nextsignal = [nextsignal signal];
                                                        nextoport = [nextoport outinportPort];
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            
                        case 'ModelReference'
                            % Follow bus traversal into model reference
                            object.addToMappedArray('busCreatorBlockMap', creator, get_param(next , 'handle'));
                            dstPorts = get_param(portline, 'DstPortHandle');
                            for j = 1:length(dstPorts)
                                if get_param(get_param(dstPorts(j), 'Parent'), 'Handle') == next
                                    portNum = get_param(dstPorts(j), 'PortNumber');
                                    [tmpModels,tmpRefName] = find_mdlrefs(next,'ReturnTopModelAsLastElement', 0);
                                    load_system(tmpModels);
                                    if ~any(cellfun(@isequal, object.ReachCoreachModels, repmat({tmpModels}, size(object.ReachCoreachModels))))
                                        object.ReachCoreachModels{end+1} = tmpModels{1};
                                    end
                                    inport = find_system(tmpModels{1}, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                        'BlockType', 'Inport', 'Port', num2str(portNum));
                                    if ~isempty(inport)
                                        for k = 1:length(inport)
                                            object.addToMappedArray('busCreatorBlockMap', creator, get_param(inport{k}, 'Handle'));
                                            object.enterReachModelReferenceThroughBus(inport, tmpRefName, tmpModels, creator, signal);
                                            exit = [];
                                        end
                                    end
                                end
                            end
                            
                        case 'Outport'
                            % Follow the bus out of Subsystems
                            object.addToMappedArray('busCreatorBlockMap', creator, get_param(next , 'Handle'));
                            portNum = get_param(next, 'Port');
                            parent = get_param(next, 'parent');
                            grandParent = get_param(parent, 'parent');
                            if ~strcmp(grandParent, '') && ~strcmp(grandParent, currentmodel)
                                isVariant = get_param(grandParent, 'Variant');
                            else
                                isVariant = 'off';
                            end
                            if strcmp(isVariant, 'on')
                                object.addToMappedArray('busCreatorBlockMap', creator,get_param(parent, 'handle'));
                                nextOutport = find_system(grandParent, 'SearchDepth', 1, 'BlockType', 'Outport', 'Port', portNum);
                                object.addToMappedArray('busCreatorBlockMap', creator, get_param(nextOutport{1}, 'handle'));
                                portSub = find_system(get_param(grandParent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                    'type', 'port', 'parent', grandParent, 'PortType', 'outport', 'PortNumber', str2double(portNum));
                                object.addToMappedArray('busCreatorBlockMap', creator,get_param(grandParent, 'handle'));
                                for i = 1:length(portSub)
                                    nextsignal = [nextsignal signal];
                                end
                                nextoport = [nextoport portSub];
                            else    
                            if ~isempty(get_param(parent, 'parent'))
                                object.addToMappedArray('busCreatorBlockMap', creator, get_param(parent, 'Handle'));
                                port = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                        'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2double(portNum));
%                                     try
%                                         connectedBlock = get_param(get_param(port, 'line'), 'DstBlockHandle');
%                                     catch
%                                         break
%                                     end
                                    
                                    bus_elements = get_param(next,'Element');
                                    if ~isempty(bus_elements) % Using Out Bus elements
                                        tmpsignal = split(string(bus_elements),'.');
                                        if length(tmpsignal) <= 1
                                            signalName = tmpsignal;
                                            signalName = strcat(signalName, '.', signal{1}{end});
                                        else
                                            % Handles multi level buses
                                            signalName = cell(1,length(tmpsignal));
                                            signalName{1} = strcat(tmpsignal{end}, '.', signal{1}{end});
                                            for i = 2:length(tmpsignal)
                                                signalName{i} = strcat(tmpsignal{end-i+1},'.',signalName{i-1});
                                            end
                                        end
                                        for i = 1:length(port)
                                            nextsignal = [nextsignal {[signal{1} signalName]}];
                                        end
                                        nextoport = [nextoport port];
                                    else
                                        for i = 1:length(port)
                                            nextsignal = [nextsignal signal];
                                        end
                                        nextoport = [nextoport port];
                                    end
                                end
                            end
                            
                        otherwise
                            object.addToMappedArray('busCreatorBlockMap', creator, next);
                            nextPorts = get_param(next, 'PortHandles');
                            nextPorts = nextPorts.Outport;
                            for i = 1:length(nextPorts)
                                nextsignal = [nextsignal signal];
                            end
                            nextoport = [nextoport nextPorts];
                    end
                end
            end
                    end
        
        function [buspath, busblocklist, busexit] = traverseBusBackwardsHandler(object, iport, signal, currentmodel)
            % TRAVERSEBUSBACKWARDSHANDLER Starts coreach bus process wrapper
            % Links the traverseBusForwards and reach processes
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       iport
            %       signal
            %       currentmodel
            %
            %   Outputs:
            %       buspath
            %       busblocklist
            %       busexit
            
            % nextports and signals are paired
            % Their varables are connected by order
            nextports = iport;
            signals = [{signal}]; % This is an array of cell arrays of cell arrays
            buspath = [];
            busblocklist = [];
            busexit = [];
            while ~isempty(nextports)
                iport = nextports(end);
                nextports(end) = [];
                isignal = signals(end);
                signals(end) = [];
                [buspath, busblocklist, exit, addsignal, addports] = object.traverseBusBackwards(iport, isignal, buspath, busblocklist, currentmodel);
                nextports = [nextports addports];
                signals = [signals addsignal];
                if ~isempty(exit)
                    busexit = [busexit exit]; % Get bus traversal exits
                end
            end
            buspath = unique(buspath);
            busblocklist = unique(busblocklist);
        end
        
        function [path, blockList, exit, nextsignal, nextiport] = traverseBusBackwards(object, iport, signal, path, blockList, currentmodel)
            % TRAVERSEBUSBACKWARDS Go until Bus Creator is encountered. Then,
            % return the path taken there as well as the exiting port.
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       iport
            %       signal
            %       path
            %       blockList
            %
            %   Outputs:
            %       path
            %       blockList
            %       exit
            
            exit = [];
            nextsignal = [];
            nextiport = [];
            
            for h = 1:length(iport)
                % Stops infinite loops
                if any(path == iport(h)) 
                    continue
                end
                
                blockList(end + 1) = get_param(get_param(iport(h), 'parent'), 'Handle');
                portLine = get_param(iport(h), 'line');

                if (portLine == -1)
                   return 
                end
                
                srcBlocks = get_param(portLine, 'SrcBlockHandle');
                path(end + 1) = iport(h);
                blockList(end + 1) = portLine;
                signalhierarchy = get_param(iport(h), 'SignalHierarchy');
                
                if isempty(srcBlocks)
                    exit = [];
                    continue
                end
                
                next = srcBlocks(1);
                next = get_param(next, 'Handle');
                blockType = get_param(next, 'BlockType');
                nextPorts = get_param(next, 'PortHandles');
                
                % If the bus ends early (not at Bus Selector) output empty
                % dest and exit
                switch blockType
                    case 'BusSelector'
                        %  If another Bus Selector is encountered, call the
                        %  function recursively
                        srcPort = get_param(portLine, 'SrcPortHandle');
                        portNum = get_param(srcPort, 'PortNumber');
                        tempSignal = get_param(next, 'OutputSignals');
                        tempSignal = regexp(tempSignal, ',', 'split');
                        tempSignal = tempSignal{portNum};
                        for i = 1:length(nextPorts.Inport)
                            nextsignal = [nextsignal {[signal{1} tempSignal]}];
                        end
                        nextiport = [nextiport nextPorts.Inport];
                        
                    case 'BusCreator'
                        % Case where the exit of the current bused signal is
                        % found
                        blockList(end + 1) = next;
                        inSignals = getBusCreatorSignals(next)';
                        for i = 1:length(inSignals)
                            if contains(string(signal{1}{end}),'.')
                                tmpstr = split(string(signal{1}{end}),'.');
                                index = strcmp(tmpstr(1), inSignals{i});
                            else
                                index = strcmp(string(signal{1}{end}), inSignals{i});
                            end
                            if index
                                temp = get_param(next, 'PortHandles');
                                temp = temp.Inport(i);

                                if ~isempty(regexp(signal{1}{end}, '^(([^\.]*)\.)+[^\.]*$', 'match'))
                                    % Virtual Bus case
                                    cutoff = strfind(signal{1}{end}, '.');
                                    cutoff = cutoff(1);
                                    signalName = signal{1}{end}(cutoff+1:end);
                                    nextsignal = [nextsignal {[signal{1}(1:end-1) signalName]}];
                                    nextiport = [nextiport temp];
                                else
                                    % Standard bus case
                                    if length(signal{1}) > 1
                                        nextsignal = [nextsignal {signal{1}(1:end-1)}];
                                        nextiport = [nextiport temp];
                                    else
                                        exit = [exit temp];
                                    end
                                end
                            end
                        end
                        
%                         inputs = get_param(next, 'LineHandles');
%                         inputs = inputs.Inport;
%                         inputs = get_param(inputs, 'Name');
%                         match = regexp(signal, '^signal[1-9]', 'match');
%                         if isempty(portNum)&&~isempty(match)
%                             portNum = regexp(match{1}, '[1-9]*$', 'match');
%                             portNum = str2num(portNum{1});
%                         else
%                             portNum = 1:length(inSignals);
%                         end
                        
                    case 'From'
                        % Follow the bus through From blocks
                        blockList(end + 1) = next;
                        gotos = findGotosInScopeRCR(object, next, object.gtvFlag);
                        for i = 1:length(gotos)
                            gotoPort = get_param(gotos{i}, 'PortHandles');
                            gotoPort = gotoPort.Inport;
                            for j = 1:length(gotoPort)
                                nextsignal = [nextsignal signal];
                            end
                            nextiport = [nextiport gotoPort];
                            tag = findVisibilityTagRCR(object, gotos{i}, object.gtvFlag);
                            if ~isempty(tag)
                                blockList(end + 1) = get_param(tag{1}, 'Handle');
                            end
                        end
                        
                    case 'SubSystem'
                        % Follow the bus into Subsystems
                        blockList(end + 1) = next;
                        srcPorts = get_param(portLine, 'SrcPortHandle');
                        isVariant = get_param(next, 'Variant');
                        if strcmp(isVariant, 'on')
                            % Variant subsystem case
                            for j = 1:length(srcPorts)
                                portNum = get_param(srcPorts(j), 'PortNumber');
                                outport = find_system(next, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                                outportPort = get_param(outport, 'PortHandles');
                                outportPort = outportPort.Inport;
                                blockList(end + 1) = get_param(get_param(outportPort, 'parent'), 'Handle');
                                % 1st element is of top-level variant subsystem, already in traveral path
                                
                                outportNum = get_param(outport, 'Port');
                                subsystemVariants = find_system(next, 'SearchDepth', 1, 'BlockType', 'SubSystem');
                                for k = 2:length(subsystemVariants)
                                    variantoutportPort = find_system(subsystemVariants(k), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', outportNum);
                                    outportPort = get_param(variantoutportPort, 'PortHandles');
                                    outportPort = outportPort.Inport;
                                    nextsignal = [nextsignal signal];
                                    nextiport = [nextiport outportPort];
                                end
                            end
                        else
                        for j = 1:length(srcPorts)
                            portNum = get_param(srcPorts(j), 'PortNumber');
                            outport = find_system(next, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                                bus_elements = get_param(outport,'Element');
                                if ~isempty(bus_elements) && any(not(cellfun('isempty',bus_elements)))% Using Out Bus elements (Virtual Bus)
                                    % Bus element case
                                    tempsignal = signal{1}{1};
                                    for i = 2:length(signal{1})
                                        tempsignal = strcat(signal{1}{i},'.',tempsignal);
                                    end
                                    tmpsig = split(string(tempsignal),'.');
                                    for i = 1:length(bus_elements) % For each bus entrance into subsystem
                                        tmpbus = split(string(bus_elements{i}),'.');
                                        goflag = true;
                                        for k = 1:length(tmpbus)
                                            if tmpsig(k) ~= tmpbus(k)
                                                goflag = false;
                                                break;
                                            end
                                        end
                                        if goflag % If port found
                                            temp = get_param(outport, 'PortHandles');
                                            temp = temp{i};
                                            temp = temp.Inport;
                                            if length(bus_elements{i}) == length(tempsignal) % If exact match
                                                blockList(end + 1) = outport(i);
                                                exit = [exit temp]; % Bus exit found
                                            else
                                                nextsignal = [nextsignal {signal{1}(1:end-length(tmpbus))}];
                                                nextiport = [nextiport temp];
                                            end
                                        end
                                    end
                                else
                                    % Standard case
                            outportPort = get_param(outport, 'PortHandles');
                            outportPort = outportPort.Inport;
                                    nextsignal = [nextsignal signal];
                                    nextiport = [nextiport outportPort];
                                end
                            end
                        end
                        
                    case 'ModelReference'
                        % Follow bus traversal into model reference
                        blockList(end + 1) = next;
                        srcPorts = get_param(portLine, 'SrcPortHandle');
                        for j = 1:length(srcPorts)
                            portNum = get_param(srcPorts(j), 'PortNumber');
                            [tmpModels,tmpRefName] = find_mdlrefs(next,'ReturnTopModelAsLastElement', 0);
                            load_system(tmpModels);
                            if ~any(cellfun(@isequal, object.ReachCoreachModels, repmat({tmpModels}, size(object.ReachCoreachModels))))
                                object.ReachCoreachModels{end+1} = tmpModels{1};
                            end
                            outport = find_system(tmpModels{1}, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                'BlockType', 'Outport', 'Port', num2str(portNum));
                            if ~isempty(outport)
                                for k = 1:length(outport)
                                    blockList(end + 1) = get_param(outport{k}, 'Handle');
                                    object.enterCoReachModelReferenceThroughBus(outport{k}, tmpRefName, tmpModels, signal);
                                    exit = [];
                                end    
                            end
                        end
                        
                    case 'Inport'
                        % Follow the bus out of Subsystems or end
                        portNum = get_param(next, 'Port');
                        parent = get_param(next, 'parent');
                        grandParent = get_param(parent, 'parent');
                        if ~strcmp(grandParent, '') && ~strcmp(grandParent, currentmodel)
                            isVariant = get_param(grandParent, 'Variant');
                        else
                            isVariant = 'off';
                        end
                        if strcmp(isVariant, 'on')
                            blockList(end + 1) = get_param(parent, 'Handle');
                            blockList(end + 1) = get_param(next, 'Handle');
                            nextInport = find_system(grandParent, 'SearchDepth', 1, 'BlockType', 'Inport', 'Port', portNum);
                            blockList(end + 1) = get_param(nextInport{1}, 'Handle');
                            port = find_system(get_param(grandParent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', grandParent, 'PortType', 'inport', 'PortNumber', str2double(portNum));
                            blockList(end + 1) = get_param(grandParent, 'handle');
                            for i = 1:length(port)
                            	nextsignal = [nextsignal signal];
                            end
                            nextiport = [nextiport port];
                        else
                        if ~isempty(get_param(parent, 'parent'))
                            blockList(end + 1) = get_param(parent, 'Handle');
                            blockList(end + 1) = get_param(next, 'Handle');
                            port = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                    'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2double(portNum));
                                bus_elements = get_param(next,'Element');
                                if ~isempty(bus_elements) % Using Out Bus elements
                                    tmpsignal = split(string(bus_elements),'.');
                                    if length(tmpsignal) <= 1
                                        signalName = tmpsignal;
                                    else
                                        % Handles multi level buses
                                        signalName = cell(1,length(tmpsignal));
                                        signalName{1} = tmpsignal{end};
                                        for i = 2:length(tmpsignal)
                                            signalName{i} = tmpsignal{end-i+1};
                                        end
                                    end
                                    for i = 1:length(port)
                                        nextsignal = [nextsignal {[signal{1} signalName]}];
                                    end
                                    nextiport = [nextiport port];
                                else
                                    if ~isempty(signalhierarchy.BusObject)
                                        for i = 1:length(port)
                                            nextsignal = [nextsignal signal];
                                        end
                                        nextiport = [nextiport port];
                                    else
                                        exit = [exit port];
                                    end
                                end
                        else
                            blockList(end + 1) = get_param(next, 'Handle');
                        end
                        end
                        
                    case 'BusAssignment'
                        % Follow the proper signal in a BusAssignment block
                        assignedSignals = get_param(next, 'AssignedSignals');
                        assignedSignals = regexp(assignedSignals, ',', 'split');
                        inputs = get_param(next, 'PortHandles');
                        inputs = inputs.Inport;
                        for i = 1:length(assignedSignals)
                            if(strcmp(assignedSignals(i), signal{1}{end}))
                                exit = [exit inputs(1 + i)];
                            end
                        end
                        for i = 1:length(inputs(1))
                        	nextsignal = [nextsignal signal];
                        end
                        nextiport = [nextiport inputs(1)];
                        
                    otherwise
                        blockList(end + 1) = next;
                        for i = 1:length(nextPorts.Inport)
                        	nextsignal = [nextsignal signal];
                        end
                        nextiport = [nextiport nextPorts.Inport];
                end
            end
        end
        
        function enterReachModelReferenceThroughBus(object, iport, refmodel, modelparent, creator, signal)
            % ENTERREACHMODELREFERENCETHROUGHBUS
            % Links enterReachModelReference and traverseBusForwards
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       iport
            %       refmodel
            %       modelparent
            %       creator
            %       signal
            %
            %   Outputs:
            %       N/A
            
            iporthandle = get_param(iport,'Handle');
            busPort = get_param(iporthandle{1}, 'PortHandles');
            busPort = busPort.Outport;
            [path, exit] = object.traverseBusForwardsHandler(creator, busPort, signal{1}, modelparent); % Get bus path
            object.TraversedPorts = [object.TraversedPorts path];
            enterReachModelReference(object, exit, refmodel, modelparent); % Do recursive reach call within model
        end
        
        function enterReachModelReference(object, iport, refmodel, modelparent)
            % ENTERREACHMODELREFERENCE
            % Starts recursive reach call
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       iport
            %       refmodel
            %       modelparent
            %
            %   Outputs:
            %       N/A
            
            % Temporary buffers
            tmpPortsToTraverse = object.PortsToTraverse;
            tmpTraversedPorts = object.TraversedPorts;
            tmpRecurseCell = object.RecurseCell;
            
            object.PortsToTraverse = iport;
            % Use map specific to model reference
            if isKey(object.MTraversedPorts, refmodel{1})
                object.TraversedPorts = object.MTraversedPorts(refmodel{1});
            else
                object.TraversedPorts = [];
            end
            
            outports = [];
            
            % Reach from each in the list of ports to traverse
            while ~isempty(object.PortsToTraverse)
                object.RecurseCell = setdiff(object.PortsToTraverse, object.TraversedPorts);
                object.PortsToTraverse = [];
                while ~isempty(object.RecurseCell)
                    port = object.RecurseCell(end);
                    object.RecurseCell(end) = [];
                    out = reach(object, port, modelparent);
                    if (~isempty(out))
                        outportnum = str2double(get_param(out, 'Port'));
                        outports(end+1) = find_system(get_param(refmodel{1},'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                            'type', 'port', 'parent', refmodel{1}, 'PortType', 'outport', 'PortNumber', outportnum);
                    end
                end
            end
            
            % Restore
            object.PortsToTraverse = [tmpPortsToTraverse setdiff(object.PortsToTraverse,tmpPortsToTraverse)];
            object.MTraversedPorts(refmodel{1}) = object.TraversedPorts;
            object.TraversedPorts = [tmpTraversedPorts setdiff(object.TraversedPorts,tmpTraversedPorts)];
            object.RecurseCell = tmpRecurseCell;
            
            for i = 1:length(outports)
                object.PortsToTraverse(end+1) = outports(i);
            end
        end
        
        function enterCoReachModelReferenceThroughBus(object, oport, refmodel, modelparent, signal)
            % ENTERCOREACHMODELREFERENCETHROUGHBUS
            % Links enterReachModelReference and traverseBusForwards
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       oport
            %       refmodel
            %       modelparent
            %       signal
            %
            %   Outputs:
            %       N/A
            
            oporthandle = get_param(oport,'Handle');
            busPort = get_param(oporthandle, 'PortHandles');
            busPort = busPort.Inport;
            [path, blockList, exit] = traverseBusBackwardsHandler(object, busPort, signal{1}, modelparent); % Get bus path
            object.TraversedPortsCo = [object.TraversedPortsCo path];
            object.CoreachedObjects = [object.CoreachedObjects blockList];
            enterCoReachModelReference(object, exit, refmodel, modelparent); % Do recursive coreach call within model
        end
        
        function enterCoReachModelReference(object, oport, refmodel, modelparent)
            % ENTERCOREACHMODELREFERENCE
            % Starts recursive coreach call
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       iport
            %       refmodel
            %       modelparent
            %
            %   Outputs:
            %       N/A
        
            % Temporary buffers
            tmpPortsToTraverseCo = object.PortsToTraverseCo;
            tmpTraversedPortsCo = object.TraversedPortsCo;
            
            object.PortsToTraverseCo = oport;
            % Use map specific to model reference
            if isKey(object.MTraversedPortsCo, refmodel{1})
                object.TraversedPortsCo = object.MTraversedPortsCo(refmodel{1});
            else
                object.TraversedPortsCo = [];
            end
            
            inports = [];
            
            % Reach from each in the list of ports to traverse
            while ~isempty(object.PortsToTraverseCo)
                port = object.PortsToTraverseCo(end);
                object.PortsToTraverseCo(end) = [];
                in = coreach(object, port, modelparent);
                if (~isempty(in))
                    inportnum = str2double(get_param(in, 'Port'));
                    inports(end+1) = find_system(get_param(refmodel{1},'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                        'type', 'port', 'parent', refmodel{1}, 'PortType', 'inport', 'PortNumber', inportnum);
                end
            end
            
            % Restore
            object.PortsToTraverseCo = [tmpPortsToTraverseCo setdiff(object.PortsToTraverseCo,tmpPortsToTraverseCo)];
            object.MTraversedPortsCo(refmodel{1}) = object.TraversedPortsCo;
            object.TraversedPortsCo = [tmpTraversedPortsCo setdiff(object.TraversedPortsCo,tmpTraversedPortsCo)];
            
            for i = 1:length(inports)
                object.PortsToTraverseCo(end+1) = inports(i);
            end
        end
        
        function addToMappedArray(object, property, key, handle)
            % ADDTOMAPPEDARRAY
            %
            %   Inputs:
            %       object      ReachCoreach object.
            %       property
            %       key
            %       handle
            %
            %   Outputs:
            %
            
            temp = object.(property);
            try
                array = temp(key);
            catch
                array = [];
            end
            array(end + 1) = handle;
            array = unique(array);
            temp(key) = array;
            object.(property) = temp;
        end
        
    end
end
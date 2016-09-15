classdef ReachCoreach < handle
% REACHCOREACH A class that enables performing reachability/coreachability
% analysis on blocks in a model.
%
%   A reachability analysis is finding all blocks and lines that the
%   starting blocks affect via control flow and data flow. A coreachability
%   analysis finds all blocks that affect the starting blocks via control
%   flow or data flow. After creating a ReachCoreach object, the reachAll
%   and coreachAll methods are can be used to perform these analyses, 
%   and highlight all the blocks/signals in the reach and coreach.

    properties
        RootSystemName      % Simulink model name (or top-level system name).
        RootSystemHandle    % Handle of top level subsystem.
        
        ReachedObjects      % List of blocks and lines reached.
        CoreachedObjects    % List of blocks and lines coreached.
        
        TraversedPorts      % Ports already traversed in the reach operation.
        TraversedPortsCo    % Ports already traversed in the coreach operation.
    end
    
    properties(Access = private)
        PortsToTraverse     % Ports remaining to traverse in the reach operation.
        PortsToTraverseCo   % Ports remaining to traverse in the coreach operation.
        
        Color               % Foreground color of highlight.
        BGColor             % Background color of highlight.
    end
    
    methods
        function object = ReachCoreach(RootSystemName)
        % Constructor for the ReachCoreach object.
        %
        % PARAMETERS
        % RootSystemName: Parameter name of the top level system in the model
        % hierarchy the reach/coreach operations are to be run on.
        %
        % EXAMPLE
        %   obj = ReachCoreach('ModelName')
            
            % Check parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open
            try
                assert(ischar(RootSystemName));
                assert(bdIsLoaded(RootSystemName));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    'Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.'])
                return
            end
            
            % 2) Ensure that the parameter given is the top level of the
            % model
            try
                assert(strcmp(RootSystemName, bdroot(RootSystemName)))
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    'Invalid RootSystemName. Given RootSystemName is not ' ...
                    'the root level of its model.'])
                return
            end
            
            % Initialize a new instance of ReachCoreach.
            object.RootSystemName = RootSystemName;
            object.RootSystemHandle = get_param(RootSystemName, 'handle');
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            object.Color = 'red';
            object.BGColor = 'yellow';
        end
        
        function setColor(object, color1, color2)
        % Set the highlight colours for the reach/coreach.
        %
        % PARAMETERS
        % color1: Parameter for the highlight foreground colour.
        % Accepted values are 'red', 'green', 'blue', 'cyan',
        % 'magenta', 'yellow', 'black', 'white'.
        %
        % color2: Parameter for the highlight background colour.
        % Accepted values are 'red', 'green', 'blue', 'cyan',
        % 'magenta', 'yellow', 'black', 'white'.
        %
        % EXAMPLE
        %   obj.setColor('red', 'blue')
            
            % Ensure that the parameters are strings
            try
                assert(ischar(color1))
                assert(ischar(color2))
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid color(s). Accepted colors are ''red'', ''green'', ' ...
                    '''blue'', ''cyan'', ''magenta'', ''yellow'', ''white'', and ''black''.'])
                return
            end
            
            % Ensure that the colour selected are acceptable
            try
                acceptedColors = {'cyan', 'red', 'blue', 'green', 'magenta', ...
                    'yellow', 'white', 'black'};
                assert(isempty(setdiff(color1, acceptedColors)))
                assert(isempty(setdiff(color2, acceptedColors)))
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid color(s). Accepted colours are ''red'', ''green'', ' ...
                    '''blue'', ''cyan'', ''magenta'', ''yellow'', ''white'', and ''black''.'])
                return
            end
            % Set the desired colors for highlighting.
            object.Color = color1;
            object.BGColor = color2;
        end
        
        function hiliteObjects(object)
        % Highlight the reached/coreached blocks and lines.
        %
        % EXAMPLE 
        %   obj.hiliteObjects()

            openSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            HILITE_DATA = struct('HiliteType', 'user2', 'ForegroundColor', object.Color, 'BackgroundColor', object.BGColor);
            set_param(0, 'HiliteAncestorsData', HILITE_DATA);
            warningID='Simulink:blocks:HideContents';
            warning('off', warningID);
            hilite_system(object.ReachedObjects, 'user2');
            hilite_system(object.CoreachedObjects, 'user2');
            warning('on', warningID);
            allOpenSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            sysToClose = setdiff(allOpenSys, openSys);
            close_system(sysToClose);
            sfclose('all');
        end
        
        function slice(object)
        % Isolate the reached/coreached blocks by removing unhighlighted blocks.
        %
        % EXAMPLE
        %   obj.slice()
        
            % Ensure that there is a selection before slicing.
            try
                assert(~isempty(object.ReachedObjects))
                assert(~isempty(object.CoreachedObjects))
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' There are no reached/coreached objects' ...
                    ' to slice.'])
                return
            end

            openSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            allObjects = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line');
            allObjects = [allObjects; find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'block')];
            toKeep = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line', 'HiliteAncestors', 'user2');
            toKeep = [toKeep; find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'block', 'HiliteAncestors', 'user2')];
            toDelete = setdiff(allObjects, toKeep);
            warningID = 'MATLAB:DELETE:FileNotFound';
            warning('off', warningID);
            delete(toDelete);
            warning('on', warningID);
            brokenLines = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line', 'DstBlockHandle', -1);
            delete_line(brokenLines);
            allOpenSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            sysToClose = setdiff(allOpenSys, openSys);
            close_system(sysToClose);
            sfclose('all');
        end
        
        function clear(object)
        % Remove all reach/coreach highlighting.
        %
        % EXAMPLE
        %   obj.clear()

            openSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            hilitedObjects = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line', 'HiliteAncestors', 'user2');
            hilitedObjects = [hilitedObjects; find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'block', 'HiliteAncestors', 'user2')];
            hilite_system(hilitedObjects, 'none');
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            object.TraversedPorts = [];
            object.TraversedPortsCo = [];
            allOpenSys = find_system(object.RootSystemName, 'FollowLinks', 'on', 'BlockType', 'SubSystem', 'Open', 'on');
            sysToClose = setdiff(allOpenSys, openSys);
            close_system(sysToClose);
        end
        
        function reachAll(object, selection)
        % Reach from a selection of blocks.
        % 
        % PARAMETERS
        % selection: a cell array of strings representing the full
        % names of blocks.
        %
        % EXAMPLE
        %   obj.reachAll({'ModelName/In1', 'ModelName/SubSystem/Out2'})
            
            % Check object parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open
            try
                assert(ischar(object.RootSystemName));
                assert(bdIsLoaded(object.RootSystemName));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.'])
                return
            end
            
            % 2) Check that model M is unlocked
            try
                assert(strcmp(get_param(bdroot(object.RootSystemName), 'Lock'), 'off'))
            catch E
                if strcmp(E.identifier, 'MATLAB:assert:failed') || ...
                        strcmp(E.identifier, 'MATLAB:assertion:failed')
                    disp(['Error using ' mfilename ':' char(10) ...
                        ' File is locked.'])
                    return
                else
                    disp(['Error using ' mfilename ':' char(10) ...
                        ' Invalid RootSystemName.'])
                    return
                end
            end
            
            % Check that selection is of type 'cell'
            try
                assert(iscell(selection));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid cell argument "selection".'])
                return
            end
                        
            % Get the ports/blocks of selected blocks that are special
            % cases
            for i = 1:length(selection)
                % check that the elements of selection are existing blocks
                % in model RootSystemName
                try
                    assert(strcmp(get_param(selection{i}, 'type'), 'block'));
                    assert(strcmp(bdroot(selection{i}), object.RootSystemName));
                catch
                    disp(['Error using ' mfilename ':' char(10) ...
                       selection{i} ' is not a block in system ' object.RootSystemName '.'])
                    break
                end
                selectionType = get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    % Get all outgoing interface from subsystem, and add
                    % blocks to reach, as well as ports to the list of ports
                    % to traverse
                    outBlocks = object.getInterfaceOut(selection{i});
                    for j = 1:length(outBlocks)
                        object.ReachedObjects(end + 1) = get_param(outBlocks{j}, 'handle');
                        ports = get_param(outBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    moreBlocks = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                    for j = 1:length(moreBlocks)
                        object.ReachedObjects(end + 1) = get_param(moreBlocks{j}, 'handle');
                    end
                    lines = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
                    object.ReachedObjects = [object.ReachedObjects lines.'];
                    morePorts = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'port');
                    if iscolumn(morePorts)
                        morePorts = morePorts.';
                    end
                    portsToExclude = get_param(selection{i}, 'PortHandles');
                    portsToExclude = portsToExclude.Outport;
                    morePorts = setdiff(morePorts, portsToExclude);
                    object.TraversedPorts = [object.TraversedPorts morePorts];
                elseif strcmp(selectionType, 'Outport')
                    portNum = get_param(selection{i}, 'Port');
                    parent = get_param(selection{i}, 'parent');
                    if ~isempty(get_param(parent, 'parent'))
                        portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                            'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                        object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                        object.PortsToTraverse(end + 1) = portSub;
                    end
                elseif strcmp(selectionType, 'GotoTagVisibility')
                    % Add goto and from blocks to reach, and ports to list to traverse
                    associatedBlocks = findGotoFromsInScope(selection{i});
                    for j = 1:length(associatedBlocks)
                        object.ReachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                elseif strcmp(selectionType, 'DataStoreMemory')
                    % Add read and write blocks to reach, and ports to list
                    % to traverse
                    associatedBlocks = findReadWritesInScope(selection{i});
                    for j = 1:length(associatedBlocks)
                        object.ReachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                elseif strcmp(selectionType, 'DataStoreWrite')
                    % Add read blocks to reach, and ports to list to traverse
                    reads = findReadsInScope(selection{i});
                    for j = 1:length(reads)
                        object.ReachedObjects(end + 1) = get_param(reads{j}, 'handle');
                        ports = get_param(reads{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    mem = findDataStoreMemory(selection{i});
                    if ~isempty(mem)
                        object.ReachedObjects(end + 1) = get_param(mem, 'Handle');
                    end
                elseif strcmp(selectionType, 'DataStoreRead')
                    mem = findDataStoreMemory(selection{i});
                    if ~isempty(mem)
                        object.ReachedObjects(end + 1) = get_param(mem, 'Handle');
                    end
                elseif strcmp(selectionType, 'Goto')
                    % Add from blocks to reach, and ports to list to traverse
                    froms = findFromsInScope(selection{i});
                    for j = 1:length(froms)
                        object.ReachedObjects(end + 1) = get_param(froms{j}, 'handle');
                        ports = get_param(froms{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    tag = findVisibilityTag(selection{i});
                    if ~isempty(tag)
                        object.ReachedObjects(end + 1) = get_param(tag, 'Handle');
                    end
                elseif strcmp(selectionType, 'From')
                    tag = findVisibilityTag(selection{i});
                    if ~isempty(tag)
                        object.ReachedObjects(end + 1) = get_param(tag, 'Handle');
                    end
                elseif strcmp(selectionType, 'BusCreator')
                    busInports = get_param(selection{i}, 'PortHandles');
                    busInports = busInports.Inport;
                    for j = 1:length(busInports)
                        line = get_param(busInports(j), 'line');
                        signalName = get_param(line, 'Name');
                        if isempty(signalName)
                            portNum = get_param(busInports(j), 'PortNumber');
                            signalName = ['signal' num2str(portNum)];
                        end
                        busPort = get_param(selection{i}, 'PortHandles');
                        busPort = busPort.Outport;
                        [path, blockList, exit] = object.traverseBusForwards(busPort, signalName, [], []);
                        object.TraversedPorts = [object.TraversedPorts path];
                        object.ReachedObjects = [object.ReachedObjects blockList];
                        object.PortsToTraverse = [object.PortsToTraverse exit];
                    end
                elseif (strcmp(selectionType, 'EnablePort') || ...
                        strcmp(selectionType, 'ActionPort') || ...
                        strcmp(selectionType, 'TriggerPort') || ...
                        strcmp(selectionType, 'WhileIterator') || ...
                        strcmp(selectionType, 'ForEach') || ...
                        strcmp(selectionType, 'ForIterator'))
                    % Add everything to in a subsystem to the reach if one
                    % of the listed block types is in the selection
                    object.reachEverythingInSub(get_param(selection{i}, 'parent'))
                end
                % Add blocks to reach from selection, and their ports to the
                % list to traverse
                object.ReachedObjects(end + 1) = get_param(selection{i}, 'handle');
                ports = get_param(selection{i}, 'PortHandles');
                object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
            end
            % Reach from each in the list of ports to traverse
            while ~isempty(object.PortsToTraverse)
                port = object.PortsToTraverse(end);
                object.PortsToTraverse(end) = [];
                reach(object, port)
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
            object.hiliteObjects();
        end
        
        function coreachAll(object, selection)
        % Coreach from a selection of blocks.
        %
        % PARAMETERS
        % selection: a cell array of strings representing the full
        % names of blocks.
        %
        % EXAMPLE
        %   obj.coreachAll({'ModelName/In1', 'ModelName/SubSystem/Out2'})
            
            % Check object parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open
            try
                assert(ischar(object.RootSystemName));
                assert(bdIsLoaded(object.RootSystemName));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.'])
                return
            end
            
            % 2) Check that model M is unlocked
            try
                assert(strcmp(get_param(bdroot(object.RootSystemName), 'Lock'), 'off'))
            catch E
                if strcmp(E.identifier, 'MATLAB:assert:failed') || ...
                        strcmp(E.identifier, 'MATLAB:assertion:failed')
                    disp(['Error using ' mfilename ':' char(10) ...
                        ' File is locked.'])
                    return
                else
                    disp(['Error using ' mfilename ':' char(10) ...
                        ' Invalid RootSystemName.'])
                    return
                end
            end
            
            % Check that selection is of type 'cell'
            try
                assert(iscell(selection));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid cell argument "selection".'])
                return
            end
            
            % Get the ports/blocks of selected blocks that are special
            % cases
            for i = 1:length(selection)
                % Check that the elements of selection are existing blocks
                % in model RootSystemName
                try
                    assert(strcmp(get_param(selection{i}, 'type'), 'block'));
                    assert(strcmp(bdroot(selection{i}), object.RootSystemName));
                catch
                    disp(['Error using ' mfilename ':' char(10) ...
                       selection{i} ' is not a block in system ' object.RootSystemName '.'])
                    break
                end
                selectionType = get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    % Get all incoming interface to subsystem, and add
                    % blocks to coreach, as well as ports to the list of ports
                    % to traverse
                    inBlocks = object.getInterfaceIn(selection{i});
                    for j = 1:length(inBlocks)
                        object.CoreachedObjects(end + 1) = get_param(inBlocks{j}, 'handle');
                        ports = get_param(inBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    moreBlocks = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                    for j = 1:length(moreBlocks)
                        object.CoreachedObjects(end + 1) = get_param(moreBlocks{j}, 'handle');
                    end
                    lines = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
                    object.CoreachedObjects = [object.CoreachedObjects lines.'];
                    morePorts = find_system(selection{i}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'port');
                    if iscolumn(morePorts)
                        morePorts = morePorts.';
                    end
                    portsSub = get_param(selection{i}, 'PortHandles');
                    portsToExclude = [portsSub.Inport portsSub.Trigger portsSub.Enable portsSub.Ifaction];
                    morePorts = setdiff(morePorts, portsToExclude);
                    object.TraversedPortsCo = [object.TraversedPortsCo morePorts];
                elseif strcmp(selectionType, 'Inport')
                    portNum = get_param(selection{i}, 'Port');
                    parent = get_param(selection{i}, 'parent');
                    if ~isempty(get_param(parent, 'parent'))
                        portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                            'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2num(portNum));
                        object.CoreachedObjects(end + 1) = get_param(parent, 'handle');
                        object.PortsToTraverseCo(end + 1) = portSub;
                    end
                elseif strcmp(selectionType, 'GotoTagVisibility')
                    % Add goto and from blocks to coreach, and ports to list to
                    % traverse
                    associatedBlocks = findGotoFromsInScope(selection{i});
                    for j = 1:length(associatedBlocks)
                        object.CoreachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                elseif strcmp(selectionType, 'DataStoreMemory')
                    % Add read and write blocks to coreach, and ports to list
                    % to traverse
                    associatedBlocks = findReadWritesInScope(selection{i});
                    for j = 1:length(associatedBlocks)
                        object.CoreachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                elseif strcmp(selectionType, 'From')
                    % Add goto blocks to coreach, and ports to list to
                    % traverse
                    gotos = findGotosInScope(selection{i});
                    for j = 1:length(gotos)
                        object.CoreachedObjects(end + 1) = get_param(gotos{j}, 'handle');
                        ports = get_param(gotos{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    tag = findVisibilityTag(selection{i});
                    if ~isempty(tag)
                        object.CoreachedObjects(end + 1) = get_param(tag, 'Handle');
                    end
                elseif strcmp(selectionType, 'Goto')
                    tag = findVisibilityTag(selection{i});
                    if ~isempty(tag)
                        object.CoreachedObjects(end + 1) = get_param(tag, 'Handle');
                    end
                elseif strcmp(selectionType, 'DataStoreRead')
                    % Add write blocks to coreach, and ports to list to
                    % traverse
                    writes = findWritesInScope(selection{i});
                    for j = 1:length(writes)
                        object.CoreachedObjects(end + 1) = get_param(writes{j}, 'handle');
                        ports = get_param(writes{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    mem = findDataStoreMemory(selection{i});
                    if ~isempty(mem)
                        object.CoreachedObjects(end + 1) = get_param(mem, 'Handle');
                    end
                elseif strcmp(selectionType, 'DataStoreWrite')
                    mem = findDataStoreMemory(selection{i});
                    if ~isempty(mem)
                        object.CoreachedObjects(end + 1) = get_param(mem, 'Handle');
                    end
                elseif strcmp(selectionType, 'BusSelector')
                    busOutports = get_param(selection{i}, 'PortHandles');
                    busOutports = busOutports.Outport;
                    for j = 1:length(busOutports)
                        portNum = get_param(busOutports(j), 'PortNumber');
                        signal = get_param(selection{i}, 'OutputSignals');
                        signal = regexp(signal, ',', 'split');
                        signal = signal{portNum};
                        busPort=get_param(selection{i}, 'PortHandles');
                        [path, blockList, exit] = object.traverseBusBackwards(busPort.Inport, signal, [], []);
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
                end
                % Add blocks to coreach from selection, and their ports to the
                % list to traverse
                object.CoreachedObjects(end + 1) = get_param(selection{i}, 'handle');
                ports = get_param(selection{i}, 'PortHandles');
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Enable];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Trigger];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Ifaction];
            end
            flag = true;
            while flag
                % Coreach from each in the list of ports to traverse
                while ~isempty(object.PortsToTraverseCo)
                    port = object.PortsToTraverseCo(end);
                    object.PortsToTraverseCo(end) = [];
                    coreach(object, port)
                end
                % Add any iterators in the coreach to blocks coreached and
                % their ports to list to traverse
                iterators = findIterators(object);
                if ~isempty(iterators);
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
            object.hiliteObjects();
        end
    end
        
    methods(Access = private)
        function reach(object, port)
        % Find the next ports to call the reach from, and add all
        % objects encountered to Reached Objects.
            
            % Check if this port was already traversed
            if any(object.TraversedPorts == port)
                return
            end
            
            % Get block port belongs to
            block = get_param(port, 'parent');
            
            % Mark this port as traversed
            object.TraversedPorts(end + 1) = port;
            
            % gGet line from the port, and then get the destination blocks
            line = get_param(port, 'line');
            if (line == -1)
                return
            end
            object.ReachedObjects(end + 1) = line;
            nextBlocks = get_param(line, 'DstBlockHandle');
            
            for i = 1:length(nextBlocks)
                if (nextBlocks(i) == -1)
                    break
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
                        froms = findFromsInScope(getfullname(nextBlocks(i)));
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
                        tag = findVisibilityTag(getfullname(nextBlocks(i)));
                        if ~isempty(tag)
                            object.ReachedObjects(end + 1) = get_param(tag, 'Handle');
                        end
                    case 'DataStoreWrite'
                        % Handles the case where the next block is a data store
                        % write. Finds all data store reads and adds their
                        % outgoing ports to the list of ports to traverse
                        reads = findReadsInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(reads)
                            object.ReachedObjects(end + 1) = get_param(reads{j}, 'Handle');
                            outport = get_param(reads{j}, 'PortHandles');
                            outport = outport.Outport;
                            object.PortsToTraverse(end + 1) = outport;
                        end
                        % Adds associated data store memory block to the
                        % reach
                        mem = findDataStoreMemory(getfullname(nextBlocks(i)));
                        if ~isempty(mem)
                            object.ReachedObjects(end + 1) = get_param(mem, 'Handle');
                        end

                    case 'SubSystem'
                        % Handles the case where the next block is a
                        % subsystem. Adds corresponding inports inside
                        % subsystem to reach and adds their outgoing ports
                        % to list of ports to traverse
                        dstPorts = get_param(line, 'DstPortHandle');
                        for j = 1:length(dstPorts)
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
                                inport = find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                    'BlockType', 'Inport', 'Port', num2str(portNum));
                                if ~isempty(inport)
                                    object.ReachedObjects(end + 1) = get_param(inport, 'Handle');
                                    outport = get_param(inport, 'PortHandles');
                                    outport = outport.Outport;
                                    object.PortsToTraverse(end + 1) = outport;
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
                        if ~isempty(get_param(parent, 'parent'))
                            portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                            object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                            object.PortsToTraverse(end + 1) = portSub;
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
                        signalName = get_param(line, 'Name');
                        dstPort = get_param(line, 'DstPortHandle');
                        for j = 1:length(dstPort)
                            if isempty(signalName)
                                portNum = get_param(dstPort(j), 'PortNumber');
                                signalName = ['signal' num2str(portNum)];
                            end
                            if strcmp(get_param(get_param(dstPort(j), 'parent'), 'BlockType'), 'BusCreator')
                                busPort = get_param(nextBlocks(i), 'PortHandles');
                                busPort = busPort.Outport;
                                [path, blockList, exit] = object.traverseBusForwards(busPort, signalName, [], []);
                                object.TraversedPorts = [object.TraversedPorts path];
                                object.ReachedObjects = [object.ReachedObjects blockList];
                                object.PortsToTraverse = [object.PortsToTraverse exit];
                            end
                        end
                        
                    case 'BusAssignment'
                        assignedSignals = get_param(nextBlocks(i), 'AssignedSignals');
                        assignedSignals = regexp(assignedSignals, ',', 'split');
                        dstPorts = get_param(line, 'DstPortHandle');
                        blockInports = get_param(nextBlocks(i), 'PortHandles');
                        busPort = blockInports.Outport;
                        blockInports = blockInports.Inport;
                        inter = intersect(blockInports, dstPorts);
                        portNumbers = get_param(inter, 'PortNumber');
                        for j = 1:length(portNumbers)
                            %for each port, iterate reaching through nested
                            %buses
                            if iscell(portNumbers)
                                signalToReach = assignedSignals{portNumbers{j} - 1};
                            else
                                signalToReach = assignedSignals{portNumbers(j) - 1};
                            end
                            flag = true;
                            while flag
                                [path, blockList, exit] = object.traverseBusForwards(busPort, signalToReach, [], []);
                                object.TraversedPorts = [object.TraversedPorts path];
                                object.ReachedObjects = [object.ReachedObjects blockList];
                                dots = strfind(signalToReach, '.');
                                if isempty(dots)
                                    flag = false;
                                else
                                    signalToReach = signalToReach(1:dots(end)-1);
                                end
                                busPort = exit;
                            end
                        end
                        object.PortsToTraverse = [object.PortsToTraverse exit];
                        
                    case 'Mux'
                        dstPort = get_param(line, 'DstPortHandle');
                        for j = 1:length(dstPort)
                            muxPort = get_param(nextBlocks(i), 'PortHandles');
                            muxPort = muxPort.Outport;
                            portNum = get_param(dstPort(j), 'PortNumber');
                            [path, blockList, exit] = object.traverseMuxForwards(muxPort, portNum, [], []);
                            object.TraversedPorts = [object.TraversedPorts path];
                            object.ReachedObjects = [object.ReachedObjects blockList];
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
                                for j = 1:length(expressions)
                                    if regexp(expressions{j}, cond)
                                        object.PortsToTraverse(end + 1) = outports(j);
                                    end
                                end
                                if strcmp(get_param(nextBlocks(i), 'ShowElse'), 'on')
                                    object.PortsToTraverse(end + 1) = outports(end);
                                end
                            end
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
        
        function coreach(object, port)
        % Find the next ports to find the coreach from,
        % and add all objects encountered to coreached objects.
                        
            % Check if this port was already traversed
            if any(object.TraversedPortsCo == port)
                return
            end
            
            % Get the block port it belongs to
            block = get_param(port, 'parent');
            
            % Mark this port as traversed
            object.TraversedPortsCo(end + 1) = port;
            
            % Get the line from the port, and then get the destination blocks
            line = get_param(port, 'line');
            if (line == -1)
                return
            end
            object.CoreachedObjects(end + 1) = line;
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
                        gotos = findGotosInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(gotos)
                            object.CoreachedObjects(end + 1) = get_param(gotos{j}, 'handle');
                            inport = get_param(gotos{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        % Adds the associated goto tag visibility block to
                        % the list of coreached objects
                        tag = findVisibilityTag(getfullname(nextBlocks(i)));
                        if ~isempty(tag)
                            object.CoreachedObjects(end + 1) = get_param(tag, 'Handle');
                        end

                    case 'DataStoreRead'
                        % Handles the case where the next block is a data
                        % store read block. Finds all gotos associated with
                        % the write block, adds them to the coreached
                        % blocks, then adds their respective inports to the
                        % list of ports to traverse
                        writes = findWritesInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(writes)
                            object.CoreachedObjects(end + 1) = get_param(writes{j}, 'Handle');
                            inport = get_param(writes{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        % Adds the associated data store memory block to
                        % the list of coreached objects
                        mem = findDataStoreMemory(getfullname(nextBlocks(i)));
                        if ~isempty(mem)
                            object.CoreachedObjects(end + 1) = get_param(mem, 'Handle');
                        end

                    case 'SubSystem'
                        % Handles the case where the next block is a
                        % subsystem. Finds outport block corresponding to
                        % the outport of the subsystem, adds it to the
                        % list of coreached objects, then adds its inport to
                        % the list of inports to traverse
                        srcPorts = get_param(line, 'SrcPortHandle');
                        for j = 1:length(srcPorts)
                            portNum = get_param(srcPorts(j), 'PortNumber');
                            outport = find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                            if ~isempty(outport)
                                object.CoreachedObjects(end + 1) = get_param(outport, 'Handle');
                                inport = get_param(outport, 'PortHandles');
                                inport = inport.Inport;
                                object.PortsToTraverseCo(end + 1) = inport;
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
                        if ~isempty(get_param(parent, 'parent'))
                            portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2num(portNum));
                            object.CoreachedObjects(end + 1) = get_param(parent, 'handle');
                            object.PortsToTraverseCo(end + 1) = portSub;
                        end

                    case 'BusSelector'
                        % Handles the case where the next block is a bus
                        % selector. Follows the signal going into the bus
                        % and adds the path through the bus to the list of
                        % coreached objects. Adds the corresponding exit
                        % port on the bus creator to the list of ports to
                        % traverse
                        portBus = get_param(line, 'SrcPortHandle');
                        portNum = get_param(portBus, 'PortNumber');
                        signal = get_param(nextBlocks(i), 'OutputSignals');
                        signal = regexp(signal, ',', 'split');
                        signal = signal{portNum};
                        busPort=get_param(nextBlocks(i), 'PortHandles');
                        [path, blockList, exit] = object.traverseBusBackwards(busPort.Inport, signal, [], []);
                        object.TraversedPortsCo = [object.TraversedPortsCo path];
                        object.CoreachedObjects = [object.CoreachedObjects blockList];
                        object.PortsToTraverseCo = [object.PortsToTraverseCo exit];
                        
                    case 'Demux'
                        %case for when the next block is a demux
                        srcPort = get_param(line, 'SrcPortHandle');
                        for j = 1:length(srcPort)
                            muxPort = get_param(nextBlocks(i), 'PortHandles');
                            muxPort = muxPort.Inport;
                            portNum = get_param(srcPort(j), 'PortNumber');
                            [path, blockList, exit] = object.traverseMuxBackwards(muxPort, portNum, [], []);
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
                            expressions = regexp(expressions, ', ', 'split');
                            expressions = [{get_param(nextBlocks(i), 'IfExpression')} expressions];
                        else
                            expressions = {};
                            expressions{end + 1} = get_param(nextBlocks(i), 'IfExpression');
                        end
                        if portNum > length(expressions)
                            % Else case
                            ifPorts = get_param(nextBlocks(i), 'PortHandles');
                            ifPorts = ifPorts.Inport;
                            object.PortsToTraverseCo = [object.PortsToTraverseCo ifPorts];
                        else
                            conditions = regexp(expressions{portNum}, 'u[1-9]+', 'match');
                            for j = 1:length(conditions)
                                cond = conditions{j};
                                cond = cond(2:end);
                                ifPorts = get_param(nextBlocks(i), 'PortHandles');
                                ifPorts = ifPorts.Inport;
                                object.PortsToTraverseCo(end + 1) = ifPorts(str2num(cond));
                            end
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
        % Find all while and for iterators that need to be coreached.

            iterators = {};
            candidates = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'WhileIterator');
            candidates = [candidates find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ForIterator')];
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
        % Find all actionport, foreach, triggerport, and enableport blocks
        % and adds them to the coreach, as well as adding their
        % corresponding port in the parent subsystem block to the list
        % of ports to traverse.
        
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
        % Add all blocks and outports of blocks in the subsystem to the 
        % lists of reached objects. Also find all interface going outward
        % (outports, gotos, froms) and find the next blocks/ports as if
        % being reached by the main reach function.

            blocks = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
            
            % Excludes trigger, enable, and action port blocks (they are
            % added in main function)
            blocksToExclude = find_system(system, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'EnablePort');
            blocksToExclude = [blocksToExclude; find_system(system, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'TriggerPort')];
            blocksToExclude = [blocksToExclude; find_system(system, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ActionPort')];
            blocks = setdiff(blocks, blocksToExclude);
            
            for i = 1:length(blocks)
                object.ReachedObjects(end + 1) = get_param(blocks{i}, 'handle');
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
                        'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                    object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                    object.PortsToTraverse(end + 1) = port;
                end
            end
            
            % Handles gotos the same as the reach function
            gotos = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto');
            for j = 1:length(gotos)
                froms = findFromsInScope(gotos{j});
                for k = 1:length(froms)
                    object.ReachedObjects(end + 1) = get_param(froms{k}, 'handle');
                    outport = get_param(froms{k}, 'PortHandles');
                    outport = outport.Outport;
                    object.PortsToTraverse(end + 1) = outport;
                end
                tag = findVisibilityTag(gotos{j});
                if ~isempty(tag)
                    if iscell(tag)
                        tag=tag{1};
                    end
                    object.ReachedObjects(end + 1) = get_param(tag, 'Handle');
                end
            end
            
            % Handles writes the same as the reach function
            writes = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite');
            for j = 1:length(writes)
                reads = findReadsInScope(writes{j});
                for k = 1:length(reads)
                    object.ReachedObjects(end + 1) = get_param(reads{k}, 'Handle');
                    outport = get_param(reads{k}, 'PortHandles');
                    outport = outport.Outport;
                    object.PortsToTraverse(end + 1) = outport;
                end
                mem = findDataStoreMemory(writes{j});
                if ~isempty(mem)
                    if iscell(mem)
                        mem=mem{1};
                    end
                    object.ReachedObjects(end + 1) = get_param(mem, 'Handle');
                end
            end
        end
        
        function blocks = getInterfaceIn(object, subsystem)
        % Get all the source blocks for the subsystem, including Gotos
        % and Data Store Writes.

            blocks = {};
            gotos = {};
            writes = {};
            froms = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'From');
            allTags = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'GotoTagVisibility');
            for i = 1:length(froms)
                gotos = [gotos; findGotosInScope(froms{i})];
                tag = findVisibilityTag(froms{i});
                tag = setdiff(tag, allTags);
                if ~isempty(tag)
                    if iscell(tag)
                        tag = tag{1};
                    end
                    object.CoreachedObjects(end + 1) = get_param(tag, 'Handle');
                end
            end
            gotos = setdiff(gotos, find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto'));
            
            reads = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreRead');
            allMems = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreMemory');
            for i = 1:length(reads)
                writes = [writes; findWritesInScope(reads{i})];
                mem = findDataStoreMemory(reads{i});
                mem = setdiff(mem, allMems);
                if ~isempty(mem)
                    if iscell(mem)
                        mem = mem{1};
                    end
                    object.CoreachedObjects(end + 1) = get_param(mem, 'Handle');
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
        % Get all the destination blocks for the subsystem, including
        % Froms and Data Store Reads.

            blocks = {};
            froms = {};
            reads = {};
            gotos = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto');
            allTags = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'GotoTagVisibility');
            for i = 1:length(gotos)
                froms = [froms; findFromsInScope(gotos{i})];
                tag = findVisibilityTag(gotos{i});
                tag = setdiff(tag, allTags);
                if ~isempty(tag)
                    if iscell(tag)
                        tag = tag{1};
                    end
                    object.ReachedObjects(end + 1) = get_param(tag, 'Handle');
                end
            end
            froms = setdiff(froms, find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'From'));
            
            writes = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite');
            allMems = find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreMemory');
            for i = 1:length(writes)
                reads = [reads; findReadsInScope(writes{i})];
                mem = findDataStoreMemory(writes{i});
                mem = setdiff(mem, allMems);
                if ~isempty(mem)
                    if iscell(mem)
                        mem=mem{1};
                    end
                    object.ReachedObjects(end + 1) = get_param(mem, 'Handle');
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
        
        function [path, blockList, exit] = traverseBusForwards(object, oport, signal, path, blockList)
        % Go until a Bus Creator is enoucntered. Then, return the path 
        % taken there as well as the exiting port.

            exit = [];
            for g = 1:length(oport)
                parentBlock = get_param(get_param(oport(g), 'parent'), 'Handle');
                if strcmp(get_param(parentBlock, 'BlockType'), 'S-Function');
                    exit = [exit, oport(g)];
                    break
                end
                blockList(end + 1) = parentBlock;
                portline = get_param(oport(g), 'line');
                dstBlocks = get_param(portline, 'DstBlockHandle');
                blockList(end + 1) = portline;
                path(end + 1) = oport(g);
               
                % If the bus ends early (not at Bus Selector) output empty
                % dest and exit
                if isempty(dstBlocks)
                    dest = [];
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
                                for i = 1:length(dstPort)
                                    portNum = get_param(dstPort(g), 'PortNumber');
                                    signalName = ['signal' num2str(portNum) '.' signal];
                                    [path, blockList, intermediate] = object.traverseBusForwards(nextports.Outport, ...
                                        signalName, path, blockList);
                                    path = [path intermediate];
                                    for j = 1:length(intermediate)
                                        [tempPath, tempBlockList, tempExit] = object.traverseBusForwards(intermediate(j), ...
                                            signal, path, blockList);
                                        exit = [exit tempExit];
                                        blockList = [blockList tempBlockList];
                                        path = [path, tempPath];
                                    end
                                end
                            else
                                signalName = [signalName '.' signal];
                                [path, blockList, intermediate] = object.traverseBusForwards(nextports.Outport, ...
                                    signalName, path, blockList);
                                for i = 1:length(intermediate)
                                    [tempPath, tempBlockList, tempExit] = object.traverseBusForwards(intermediate(i), ...
                                        signal, path, blockList);
                                    exit = [exit tempExit];
                                    blockList = [blockList tempBlockList];
                                    path = [path, tempPath];
                                end
                            end

                        case 'BusSelector'
                            % Base case for recursion: Get the exiting
                            % port from the Bus Selector and pass out all
                            % other relevant information
                            blockList(end + 1) = get_param(next , 'handle');
                            outputs = get_param(next, 'OutputSignals');
                            outputs = regexp(outputs, ',', 'split');
                            portNum = find(strcmp(outputs(:), signal));
                            if ~isempty(portNum)
                                temp = get_param(next, 'PortHandles');
                                temp = temp.Outport;
                                exit = [exit temp(portNum)];
                            else
                                for i = 1:length(outputs)
                                    index = strfind(signal, outputs{i});
                                    if ~isempty(index)
                                        if index(1) == 1
                                            temp = get_param(next, 'PortHandles');
                                            temp = temp.Outport;
                                            exit = [exit temp(i)];
                                        end
                                    end
                                end
                            end

                        case 'Goto'
                            % Follow the bus through Goto blocks
                            blockList(end + 1) = get_param(next , 'handle');
                            froms = findFromsInScope(next);
                            for i = 1:length(froms)
                                outport = get_param(froms{i}, 'PortHandles');
                                outport = outport.Outport;
                                [tempPath, tempBlockList, tempExit] = object.traverseBusForwards(outport, ...
                                    signal, path, blockList);
                                exit = [exit tempExit];
                                blockList = [blockList tempBlockList];
                                path = [path tempPath];
                                tag = findVisibilityTag(froms{i});
                                if ~isempty(tag)
                                    blockList(end + 1) = get_param(tag, 'Handle');
                                end
                            end

                        case 'SubSystem'
                            % Follow the bus into Subsystems
                            blockList(end + 1) = get_param(next , 'handle');
                            dstPorts = get_param(portline, 'DstPortHandle');
                            for j = 1:length(dstPorts)
                                if strcmp(get_param(dstPorts(j), 'parent'), getfullname(next))
                                    portNum = get_param(dstPorts(j), 'PortNumber');
                                    inport = find_system(next, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Inport', 'Port', num2str(portNum));
                                    inportPort = get_param(inport, 'PortHandles');
                                    inportPort = inportPort.Outport;
                                    [path, blockList, tempExit] = object.traverseBusForwards(inportPort, ...
                                        signal, path, blockList);
                                    exit = [exit tempExit];
                                end
                            end

                        case 'Outport'
                            % Follow the bus out of Subsystems
                            blockList(end + 1) = get_param(next , 'handle');
                            portNum = get_param(next, 'Port');
                            parent = get_param(next, 'parent');
                            if ~isempty(get_param(parent, 'parent'))
                                blockList(end + 1) = get_param(parent, 'Handle');
                                port = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                    'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                                path(end + 1) = port;
                                blockList(end + 1) = get_param(port, 'line');
                                connectedBlock = get_param(get_param(port, 'line'), 'DstBlockHandle');
                                [path, blockList, temp] = object.traverseBusForwards(port, ...
                                    signal, path, blockList);
                                exit = [exit temp];
                            end

                        case 'BusToVector'
                            %goes backwards through the bus to find the
                            %port that the signal originates from in the
                            %BusCreator, then use that as the signal num
                            %for traversing the bus
                            nextPorts = get_param(next, 'PortHandles');
                            prevPorts = nextPorts.Inport;
                            nextPorts = nextPorts.Outport;
                            [~, ~, startPort] = object.traverseBusBackwards(prevPorts, ...
                                signal, [], []);
                            signalNum = get_param(startPort, 'PortNumber');
                            [path, blockList, temp] = object.traverseMuxForwards(nextPorts, ...
                                signalNum, path, blockList);
                            exit = [exit temp];

                        otherwise
                            nextPorts = get_param(next, 'PortHandles');
                            nextPorts = nextPorts.Outport;
                            [path, blockList, temp] = object.traverseBusForwards(nextPorts, ...
                                signal, path, blockList);
                            exit = [exit temp];
                    end
                end
            end
        end
        
        function [path, blockList, exit] = traverseBusBackwards(object, iport, signal, path, blockList)
        % Go until Bus Creator is encountered. Then, return the path 
        % taken there as well as the exiting port.

            exit = [];
            for h = length(iport)
                blockList(end + 1) = get_param(get_param(iport(h), 'parent'), 'Handle');
                portLine = get_param(iport(h), 'line');
                srcBlocks = get_param(portLine, 'SrcBlockHandle');
                path(end + 1) = iport(h);
                blockList(end + 1) = portLine;
                
                if isempty(srcBlocks)
                    exit = [];
                    return
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
                        [path, blockList, intermediate] = object.traverseBusBackwards(nextPorts.Inport, ...
                            tempSignal, path, blockList);
                        path = [path intermediate];
                        for i = 1:length(intermediate)
                            [tempPath, tempBlockList, tempExit] = object.traverseBusBackwards(intermediate(i), ...
                                signal, path, blockList);
                            exit = [exit tempExit];
                            blockList = [blockList tempBlockList];
                            path = [path, tempPath];
                        end
                        
                    case 'BusCreator'
                        % Case where the exit of the current bused signal is
                        % found
                        blockList(end + 1) = next;
                        inputs = get_param(next, 'LineHandles');
                        inputs = inputs.Inport;
                        inputs = get_param(inputs, 'Name');
                        portNum = find(strcmp(signal, inputs));
                        if isempty(portNum)
                            match = regexp(signal, '^signal[1-9]', 'match');
                            portNum = regexp(match{1}, '[1-9]*$', 'match');
                            portNum = str2num(portNum{1});
                        end
                        temp = get_param(next, 'PortHandles');
                        temp = temp.Inport;
                        temp = temp(portNum);
                        if ~isempty(regexp(signal, '^(([^\.]*)\.)+[^\.]*$', 'match'))
                            cutoff = strfind(signal, '.');
                            cutoff = cutoff(1);
                            signalName = signal(cutoff+1:end);
                            [tempPath, tempBlockList, tempExit] = object.traverseBusBackwards(temp, ...
                                signalName, path, blockList);
                            exit = [exit tempExit];
                            blockList = [blockList tempBlockList];
                            path = [path, tempPath];
                        else
                            exit = [exit temp];
                        end
                        
                    case 'From'
                        % Follow the bus through From blocks
                        blockList(end + 1) = next;
                        gotos = findGotosInScope(next);
                        for i = 1:length(gotos)
                            gotoPort = get_param(gotos{i}, 'PortHandles');
                            gotoPort = gotoPort.Inport;
                            [tempPath, tempBlockList, tempExit] = object.traverseBusBackwards(gotoPort, ...
                                signal, path, blockList);
                            exit = [exit tempExit];
                            blockList = [blockList tempBlockList];
                            path = [path, tempPath];
                            tag = findVisibilityTag(gotos{i});
                            if ~isempty(tag)
                                blockList(end + 1) = get_param(tag, 'Handle');
                            end
                        end
                        
                    case 'SubSystem'
                        % Follow the bus into Subsystems
                        blockList(end + 1) = next;
                        srcPorts = get_param(portLine, 'SrcPortHandle');
                        for j = 1:length(srcPorts)
                            portNum = get_param(srcPorts(j), 'PortNumber');
                            outport = find_system(next, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                            outportPort = get_param(outport, 'PortHandles');
                            outportPort = outportPort.Inport;
                            [path, blockList, temp] = object.traverseBusBackwards(outportPort, signal, path, blockList);
                            exit = [exit temp];
                        end
                        
                    case 'Inport'
                        % Follow the bus out of Subsystems or end
                        portNum = get_param(next, 'Port');
                        parent = get_param(next, 'parent');
                        if ~isempty(get_param(parent, 'parent'))
                            blockList(end + 1) = get_param(parent, 'Handle');
                            blockList(end + 1) = get_param(next, 'Handle');
                            port = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2num(portNum));
                            path(end + 1) = port;
                            [path, blockList, temp] = object.traverseBusBackwards(port, signal, path, blockList);
                            exit = [exit temp];
                        else
                            blockList(end + 1) = get_param(next, 'Handle');
                        end
                        
                    case 'BusAssignment'
                        assignedSignals = get_param(next, 'AssignedSignals');
                        assignedSignals = regexp(assignedSignals, ',', 'split');
                        inputs = get_param(next, 'PortHandles');
                        inputs = inputs.Inport;
                        for i = 1:length(assignedSignals)
                            if(strcmp(assignedSignals(i), signal))
                                exit = [exit inputs(1 + i)];
                            end
                        end
                        [path, blockList, temp] = object.traverseBusBackwards(inputs(1), signal, path, blockList);
                        exit = [exit temp];
                        
                    otherwise
                        [path, blockList, temp] = object.traverseBusBackwards(nextPorts.Inport, signal, path, blockList);
                            exit = [exit temp];
                end
            end
        end
        
        function [path, blockList, exit] = traverseMuxForwards(object, oport, signal, path, blockList)
            %go until you hit a demux, then return the path taken there as
            %well as the exiting port
            exit = [];
            for g = 1:length(oport)
                parentBlock = get_param(get_param(oport(g), 'parent'), 'Handle');
                if strcmp(get_param(parentBlock, 'BlockType'), 'S-Function');
                    exit = [exit, oport(g)];
                    break
                end
                blockList(end + 1) = parentBlock;
                line = get_param(oport(g), 'line');
                dstBlocks = get_param(line, 'DstBlockHandle');
                path(end + 1) = oport(g);
                blockList(end + 1) = line;
                %if the bus ends early (not at bus selector) output empty
                %dest and exit
                if isempty(dstBlocks)
                    break
                end
                %for each of the destination blocks
                for h = 1:length(dstBlocks)
                    next = dstBlocks(h);
                    blockType = get_param(next, 'BlockType');
                    switch blockType
                        case 'Demux'
                            %base case for recursion, get the exiting
                            %port from the mux and pass out all
                            %other relevant information
                            portHandles = get_param(dstBlocks(h), 'PortHandles');
                            portHandles = portHandles.Outport;
                            exit = [exit portHandles(signal)];
                            blockList(end+1) = get_param(next , 'handle');
                        case 'Goto'
                            %follow bused signal through goto
                            blockList(end+1) = get_param(next , 'handle');
                            froms = findFromsInScope(next);
                            for i = 1:length(froms)
                                fromPort = get_param(froms{i}, 'handle');
                                fromPort = get_param(fromPort, 'PortHandles');
                                fromPort = fromPort.Outport;
                                [tempPath, tempBlockList, tempExit] = object.traverseMuxForwards(fromPort, ...
                                    signal, path, blockList);
                                exit = [exit tempExit];
                                blockList = [blockList tempBlockList];
                                path = [path, tempPath];
                                tag = findVisibilityTag(froms{i});
                                if ~isempty(tag)
                                    blockList(end+1) = get_param(tag, 'Handle');
                                end
                            end
                        case 'SubSystem'
                            %follow bused signal into subsystem
                            blockList(end+1) = get_param(next , 'handle');
                            dstPorts = get_param(line, 'DstPortHandle');
                            for j = 1:length(dstPorts)
                                portNum = get_param(dstPorts(j), 'PortNumber');
                                inport = find_system(next, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Inport', 'Port', num2str(portNum));
                                inport = get_param(inport, 'PortHandles');
                                inport = inport.Outport;
                                [path, blockList, tempExit] = object.traverseMuxForwards(inport, ...
                                    signal, path, blockList);
                                exit = [exit tempExit];
                            end
                        case 'Outport'
                            %follow bused signal out of subsystem
                            blockList(end+1) = get_param(next , 'handle');
                            portNum = get_param(next, 'Port');
                            parent = get_param(next, 'parent');
                            if ~isempty(get_param(parent, 'parent'))
                                blockList(end+1) = get_param(parent, 'Handle');
                                port = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                    'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                                path(end+1) = port;
                                [path, blockList, tempExit] = object.traverseMuxForwards(port, ...
                                    signal, path, blockList);
                                exit = [exit tempExit];
                            end
                        case 'BusCreator'
                            signalName = get_param(line, 'Name');
                            busPort = get_param(line, 'DstPortHandle');
                            for i = 1:length(busPort)
                                if isempty(signalName)
                                    portNum = get_param(busPort(i), 'PortNumber');
                                    signalName = ['signal' num2str(portNum)];
                                end
                                if strcmp(get_param(get_param(busPort(i), 'parent'), 'BlockType'), 'BusCreator')
                                    busPort = get_param(next, 'PortHandles');
                                    busPort = busPort.Outport;
                                    [path, blockList, intermediate] = object.traverseBusForwards(busPort, signalName, path, blockList);
                                    for j = 1:length(intermediate)
                                        [path, blockList, tempExit] = object.traverseMuxForwards(intermediate(j), ...
                                            signal, path, blockList);
                                        exit = [exit tempExit];
                                    end
                                end
                            end
                            
                        case 'BusAssignment'
                            assignedSignals = get_param(next, 'AssignedSignals');
                            assignedSignals = regexp(assignedSignals, ',', 'split');
                            dstPorts = get_param(line, 'DstPortHandle');
                            blockInports = get_param(next, 'PortHandles');
                            busPort = blockInports.Outport;
                            blockInports = blockInports.Inport;
                            inter = intersect(blockInports, dstPorts);
                            portNumbers = get_param(inter, 'PortNumber');
                            for j = 1:length(portNumbers)
                                %for each port, iterate reaching through nested
                                %buses
                                if iscell(portNumbers)
                                    signalToReach = assignedSignals{portNumbers{j} - 1};
                                else
                                    signalToReach = assignedSignals{portNumbers(j) - 1};
                                end
                                flag = true;
                                while flag
                                    [path, blockList, tempExit] = object.traverseBusForwards(busPort, signalToReach, path, blockList);
                                    dots = strfind(signalToReach, '.');
                                    if isempty(dots)
                                        flag = false;
                                    else
                                        signalToReach = signalToReach(1:dots(end)-1);
                                    end
                                    busPort = tempExit;
                                end
                            end
                            [path, blockList, tempExit] = object.traverseMuxForwards(busPort, ...
                                signal, path, blockList);
                            exit = [exit tempExit];
                            
                        otherwise
                            nextPort = get_param(next, 'PortHandles');
                            nextPort = nextPort.Outport;
                            [path, blockList, tempExit] = object.traverseMuxForwards(nextPort, ...
                                signal, path, blockList);
                            exit = [exit tempExit];
                    end
                end
            end
        end
        
        function [path, blockList, exit] = traverseMuxBackwards(object, iport, signal, path, blockList)
            %go until you hit a mux, then return the path taken there as
            %well as the exiting port
            
            exit = [];
            for g = 1:length(iport)
                blockList(end+1) = get_param(get_param(iport(g), 'parent'), 'Handle');
                line = get_param(iport(g), 'line');
                srcBlocks = get_param(line, 'SrcBlockHandle');
                path(end + 1) = iport(g);
                blockList(end + 1) = line;
                
                if isempty(srcBlocks)
                    break
                end
                
                for h = 1:length(srcBlocks)
                    
                    next = srcBlocks(h);
                    blockType = get_param(next, 'BlockType');
                    
                    %if the bus ends early (not at bus selector) output empty
                    %dest and exit
                    switch blockType
                        case 'Mux'
                            %case where the exit of the current bused signal is
                            %found
                            portHandles = get_param(next, 'PortHandles');
                            portHandles = portHandles.Inport;
                            exit = [exit portHandles(signal)];
                            blockList(end+1) = get_param(next, 'handle');
                            
                        case 'From'
                            %follow the bus through the from blocks
                            blockList(end+1) = get_param(next, 'handle');
                            gotos = findGotosInScope(next);
                            for i = 1:length(gotos)
                                gotoPort = get_param(gotos{i}, 'PortHandles');
                                gotoPort = gotoPort.Inport;
                                [path, blockList, tempExit] = object.traverseMuxBackwards(gotoPort, ...
                                    signal, path, blockList);
                                exit = [exit tempExit];
                                tag = findVisibilityTag(gotos{i});
                                if ~isempty(tag)
                                    blockList(end+1) = get_param(tag, 'Handle');
                                end
                            end
                            
                        case 'SubSystem'
                            %follow the bus into a subsystem
                            blockList(end+1) = get_param(next, 'handle');
                            srcPorts = get_param(line, 'SrcPortHandle');
                            for j = 1:length(srcPorts)
                                portNum = get_param(srcPorts(j), 'PortNumber');
                                outport = find_system(next, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                                outportPort = get_param(outport, 'PortHandles');
                                outportPort = outportPort.Inport;
                                [path, blockList, tempExit] = object.traverseMuxBackwards(outportPort, signal, path, blockList);
                                exit = [exit tempExit];
                            end
                            
                        case 'Inport'
                            %follow the bus out of the subsystem or end
                            blockList(end+1) = get_param(next, 'handle');
                            portNum = get_param(next, 'Port');
                            parent = get_param(next, 'parent');
                            if ~isempty(get_param(parent, 'parent'))
                                blockList(end+1) = get_param(parent, 'Handle');
                                port = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                    'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2num(portNum));
                                path(end+1) = port;
                                [path, blockList, tempExit] = object.traverseMuxBackwards(port, signal, path, blockList);
                                exit = [exit tempExit];
                            end
                            
                        case 'BusSelector'
                            portBus = get_param(line, 'SrcPortHandle');
                            portNum = get_param(portBus, 'PortNumber');
                            busSignal = get_param(next, 'OutputSignals');
                            busSignal = regexp(busSignal, ',', 'split');
                            busSignal = busSignal{portNum};
                            busPort=get_param(next, 'PortHandles');
                            [path, blockList, intermediate] = object.traverseBusBackwards(busPort.Inport, busSignal, path, blockList);
                            [path, blockList, tempExit] = object.traverseMuxBackwards(intermediate, signal, path, blockList);
                            exit = [exit tempExit];
                            
                        case 'BusToVector'
                            %goes backwards through the bus to find the
                            %port that the signal originates from in the
                            %BusCreator, then find the corresponding signal
                            %name for the bus traversal call
                            startPort = get_param(next, 'PortHandles');
                            startPort = startPort.Inport;
                            prev = getPrevBlock(startPort);
                            prevType = get_param(prev, 'BlockType');
                            while ~(strcmp(prevType, 'BusCreator') || strcmp(prevType, 'BusSelector'))
                                intermPort = get_param(prev, 'PortHandles');
                                intermPort = intermPort.Inport;
                                prev = getPrevBlock(intermPort);
                                try
                                    prevType = get_param(prev, 'BlockType');
                                catch
                                    prevType = '';
                                    break
                                end
                            end
                            
                            if strcmp(prevType, 'BusCreator')
                                inSignals = get_param(prev, 'LineHandles');
                                inSignals = inSignals.Inport;
                                sigName = get_param(inSignals(signal), 'Name');
                                if isempty(sigName)
                                    sigName = ['signal' num2str(signal)];
                                end
                                [path, blockList, tempExit] = object.traverseBusBackwards(startPort, sigName, path, blockList);
                                exit = [exit, tempExit];
                            elseif strcmp(prevType, 'BusSelector')
                                sigName = get_param(prev, 'OutputSignals');
                                sigName = regexp(sigName, ',', 'split');
                                sigName = sigName{signal};
                                [path, blockList, tempExit] = object.traverseBusBackwards(startPort, sigName, path, blockList);
                                exit = [exit, tempExit];
                            end
                            
                        otherwise
                            nextPort = get_param(next, 'PortHandles');
                            nextPort = nextPort.Inport;
                            [path, blockList, tempExit] = object.traverseMuxBackwards(nextPort, signal, path, blockList);
                            exit = [exit tempExit];
                    end
                end
            end
        end
    end
end
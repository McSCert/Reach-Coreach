classdef ReachCoreach < handle
%REACHCOREACH Summary of this function goes here.
%   Detailed explanation goes here.

    properties
        RootSystemName      % Simulink model name (or top-level system name)
        RootSystemHandle    % Handle of top level subsystem
        
        ReachedObjects      % List of blocks and lines reached
        CoreachedObjects    % List of blocks and lines coreached
        
        TraversedPorts      % Ports already traversed in reach operation
        TraversedPortsCo    % Ports already traversed in coreach operation
    end
    
    properties(Access=private)
        PortsToTraverse     % Ports remaining to traverse in reach operation
        PortsToTraverseCo   % Ports remaining to traverse in coreach operation
    end
    
    methods
        
        function object = ReachCoreach(RootSystemName)
            % Check parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open.
            try
                assert(ischar(RootSystemName));
                assert(bdIsLoaded(RootSystemName));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    'Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.' char(10)])
                help(mfilename)
                return
            end
            
            % 2) Ensure that the parameter given is the top level of the
            % model
            try
                assert(strcmp(RootSystemName, bdroot(RootSystemName)))
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    'Invalid RootSystemName. Given RootSystemName is not ' ...
                    'the root level of its model' char(10)])
                help(mfilename)
                return
            end
            
            % Initialize a new instance of ReachCoreach.
            object.RootSystemName = RootSystemName;
            object.RootSystemHandle = get_param(RootSystemName, 'handle');
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            HILITE_DATA=struct('HiliteType', 'user2', 'ForegroundColor', 'red', 'BackgroundColor', 'yellow');
            set_param(0, 'HiliteAncestorsData', HILITE_DATA);
        end
        
        function setColor(object, color1, color2)
            % ensure that the parameters are strings
            try
                assert(ischar(color1))
                assert(ischar(color2))
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid color(s). Accepted colours are ''red'', ''green'', ' ...
                    '''blue'', ''cyan'', ''magenta'', ''yellow'', ''white'', and ''black''.' char(10)])
                help(mfilename)
                return
            end
            
            % ensure that the colour selected are acceptable
            try
                acceptedColors={'cyan', 'red', 'blue', 'green', 'magenta', ...
                    'yellow', 'white', 'black'};
                assert(isempty(setdiff(color1, acceptedColors)))
                assert(isempty(setdiff(color2, acceptedColors)))
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid color(s). Accepted colours are ''red'', ''green'', ' ...
                    '''blue'', ''cyan'', ''magenta'', ''yellow'', ''white'', and ''black''.' char(10)])
                help(mfilename)
                return
            end
            % Set the desired colors for highlighting.
            HILITE_DATA=struct('HiliteType', 'user2', 'ForegroundColor', color1, 'BackgroundColor', color2);
            set_param(0, 'HiliteAncestorsData', HILITE_DATA);
        end
        
        function hiliteObjects(object)
            % Highlight the reached/coreached blocks and lines.
            hilite_system(object.ReachedObjects, 'user2');
            hilite_system(object.CoreachedObjects, 'user2');
        end
        
        function slice(object)
            % Isolate the reached/coreached blocks.
            allObjects = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'line');
            allObjects = [allObjects; find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On', 'type', 'block')];
            toDelete = setdiff(allObjects, object.ReachedObjects);
            delete(toDelete);
        end
        
        function clear(object)
            % Remove the reached/coreached blocks from selection.
            allObjects=find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'On');
            reachedCoreachedObjects=[object.ReachedObjects object.CoreachedObjects];
            missingElements=setdiff(reachedCoreachedObjects, allObjects);
            reachedCoreachedObjects=setdiff(reachedCoreachedObjects, missingElements);
            hilite_system(reachedCoreachedObjects, 'none');
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            object.TraversedPorts=[];
            object.TraversedPortsCo=[];
        end
        
        function reachAll(object, selection)
            % Public function to reach from all of a selection of blocks.
            
            % Check object parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open.
            try
                assert(ischar(object.RootSystemName));
                assert(bdIsLoaded(object.RootSystemName));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.' char(10)])
                help(mfilename)
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
                        ' Invalid RootSystemName.' char(10)])
                    help(mfilename)
                    return
                end
            end
            
            % Check that selection is of type 'cell'
            try
                assert(iscell(selection));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid cell argument "selection".' char(10)])
                help(mfilename)
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
                       selection{i} 'is not a block in system ' object.RootSystemName char(10)])
                    help(mfilename)
                    break
                end
                selectionType=get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    %get all outgoing interface from subsystem, and add
                    %blocks to reach, as well as ports to the list of ports
                    %to traverse
                    outBlocks=object.getInterfaceOut(selection{i});
                    for j=1:length(outBlocks)
                        object.ReachedObjects(end + 1) = get_param(outBlocks{j}, 'handle');
                        ports = get_param(outBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
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
                    %add goto and from blocks to reach, and ports to list to
                    %traverse
                    associatedBlocks=findGotoFromsInScope(selection{i});
                    for j=1:length(associatedBlocks)
                        object.ReachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                elseif strcmp(selectionType, 'DataStoreMemory')
                    %add read and write blocks to reach, and ports to list
                    %to traverse
                    associatedBlocks=findReadWritesInScope(selection{i});
                    for j=1:length(associatedBlocks)
                        object.ReachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                elseif strcmp(selectionType, 'DataStoreWrite')
                    %add read blocks to reach, and ports to list to
                    %traverse
                    reads=findReadsInScope(selection{i});
                    for j=1:length(reads)
                        object.ReachedObjects(end + 1) = get_param(reads{j}, 'handle');
                        ports = get_param(reads{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    mem=findDataStoreMemory(selection{i});
                    if ~isempty(mem)
                        object.ReachedObjects(end+1)=get_param(mem, 'Handle');
                    end
                elseif strcmp(selectionType, 'DataStoreRead')
                    mem=findDataStoreMemory(selection{i});
                    if ~isempty(mem)
                        object.ReachedObjects(end+1)=get_param(mem, 'Handle');
                    end
                elseif strcmp(selectionType, 'Goto')
                    %add from blocks to reach, and ports to list to
                    %traverse
                    froms=findFromsInScope(selection{i});
                    for j=1:length(froms)
                        object.ReachedObjects(end + 1) = get_param(froms{j}, 'handle');
                        ports = get_param(froms{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                    tag=findVisibilityTag(selection{i});
                    if ~isempty(tag)
                        object.ReachedObjects(end+1)=get_param(tag, 'Handle');
                    end
                elseif strcmp(selectionType, 'From')
                    tag=findVisibilityTag(selection{i});
                    if ~isempty(tag)
                        object.ReachedObjects(end+1)=get_param(tag, 'Handle');
                    end
                elseif (strcmp(selectionType, 'EnablePort') || ...
                        strcmp(selectionType, 'ActionPort') || ...
                        strcmp(selectionType, 'TriggerPort') || ...
                        strcmp(selectionType, 'WhileIterator') || ...
                        strcmp(selectionType, 'ForEach') || ...
                        strcmp(selectionType, 'ForIterator'))
                    %add everything to in a subsystem to the reach if one
                    %of the listed block types is in the selection
                    object.reachEverythingInSub(get_param(selection{i}, 'parent'))
                end
                %add blocks to reach from selection, and their ports to the
                %list to traverse
                object.ReachedObjects(end + 1) = get_param(selection{i}, 'handle');
                ports = get_param(selection{i}, 'PortHandles');
                object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
            end
            %reach from each in the list of ports to traverse
            while ~isempty(object.PortsToTraverse)
                port = object.PortsToTraverse(end);
                object.PortsToTraverse(end) = [];
                reach(object, port)
            end
            %highlight all objects reached
            object.hiliteObjects();
        end
        
        function coreachAll(object, selection)
            % Public function to get the coreach of a selection of blocks
            
            % Check object parameter RootSystemName
            % 1) Ensure the model corresponding to RootSystemName is open.
            try
                assert(ischar(object.RootSystemName));
                assert(bdIsLoaded(object.RootSystemName));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid RootSystemName. Model corresponding ' ...
                    'to RootSystemName may not be loaded or name is invalid.' char(10)])
                help(mfilename)
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
                        ' Invalid RootSystemName.' char(10)])
                    help(mfilename)
                    return
                end
            end
            
            % Check that selection is of type 'cell'
            try
                assert(iscell(selection));
            catch
                disp(['Error using ' mfilename ':' char(10) ...
                    ' Invalid cell argument "selection".' char(10)])
                help(mfilename)
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
                       selection{i} 'is not a block in system ' object.RootSystemName char(10)])
                    help(mfilename)
                    break
                end
                selectionType=get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    %get all incoming interface to subsystem, and add
                    %blocks to coreach, as well as ports to the list of ports
                    %to traverse
                    inBlocks=object.getInterfaceIn(selection{i});
                    for j=1:length(inBlocks)
                        object.CoreachedObjects(end + 1) = get_param(inBlocks{j}, 'handle');
                        ports = get_param(inBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
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
                    %add goto and from blocks to coreach, and ports to list to
                    %traverse
                    associatedBlocks=findGotoFromsInScope(selection{i});
                    for j=1:length(associatedBlocks)
                        object.CoreachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                elseif strcmp(selectionType, 'DataStoreMemory')
                    %add read and write blocks to coreach, and ports to list
                    %to traverse
                    associatedBlocks=findReadWritesInScope(selection{i});
                    for j=1:length(associatedBlocks)
                        object.CoreachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                elseif strcmp(selectionType, 'From')
                    %add goto blocks to coreach, and ports to list to
                    %traverse
                    gotos=findGotosInScope(selection{i});
                    for j=1:length(gotos)
                        object.CoreachedObjects(end + 1) = get_param(gotos{j}, 'handle');
                        ports = get_param(gotos{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    tag=findVisibilityTag(selection{i});
                    if~isempty(tag)
                        object.CoreachedObjects(end+1)=get_param(tag, 'Handle');
                    end
                elseif strcmp(selectionType, 'Goto')
                    tag=findVisibilityTag(selection{i});
                    if~isempty(tag)
                        object.CoreachedObjects(end+1)=get_param(tag, 'Handle');
                    end
                elseif strcmp(selectionType, 'DataStoreRead')
                    %add write blocks to coreach, and ports to list to
                    %traverse
                    writes=findWritesInScope(selection{i});
                    for j=1:length(writes)
                        object.CoreachedObjects(end + 1) = get_param(writes{j}, 'handle');
                        ports = get_param(writes{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    mem=findDataStoreMemory(selection{i});
                    if ~isempty(mem)
                        object.CoreachedObjects(end+1)=get_param(mem, 'Handle');
                    end
                elseif strcmp(selectionType, 'DataStoreWrite')
                    mem=findDataStoreMemory(selection{i});
                    if ~isempty(mem)
                        object.CoreachedObjects(end+1)=get_param(mem, 'Handle');
                    end
                end
                %add blocks to coreach from selection, and their ports to the
                %list to traverse
                object.CoreachedObjects(end + 1) = get_param(selection{i}, 'handle');
                ports = get_param(selection{i}, 'PortHandles');
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Enable];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Trigger];
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Ifaction];
            end
            flag=true;
            while flag
                %coreach from each in the list of ports to traverse
                while ~isempty(object.PortsToTraverseCo)
                    port = object.PortsToTraverseCo(end);
                    object.PortsToTraverseCo(end) = [];
                    coreach(object, port)
                end
                %add any iterators in the coreach to blocks coreached and
                %their ports to list to traverse
                iterators=findIterators(object);
                if ~isempty(iterators);
                    for i=1:length(iterators)
                        ports=get_param(iterators{i}, 'PortHandles');
                        object.PortsToTraverseCo=[object.PortsToTraverseCo, ports.Inport];
                        object.CoreachedObjects(end+1)=get_param(iterators{i}, 'Handle');
                    end
                end
                %add any trigger, enable, or action ports and their
                %respective blocks to the coreach and their ports to the
                %list to traverse
                object.findSpecialPorts();
                %keep iterating through until there are no more
                %blocks/ports being added
                if isempty(object.PortsToTraverseCo)
                    flag=false;
                end
            end
            object.hiliteObjects();
        end
        
    end
        
    methods(Access=private)
        
        function reach(object, port)
            % This function finds the next ports to call the reach from, and
            % adds all objects encountered to Reached Objects
            
            % check if this port was already traversed
            if any(object.TraversedPorts==port)
                return
            end
            
            %get block port belongs to
            block = get_param(port, 'parent');
            
            %mark this port as traversed
            object.TraversedPorts(end + 1) = port;
            
            %get line from the port, and then get the destination blocks
            line = get_param(port, 'line');
            object.ReachedObjects(end + 1) = line;
            nextBlocks = get_param(line, 'DstBlockHandle');
            
            for i = 1:length(nextBlocks)
                %add block to list of reached objects
                object.ReachedObjects(end + 1) = nextBlocks(i);
                %get blocktype for switch case
                blockType = get_param(nextBlocks(i), 'BlockType');
                %switch statement that handles the reaching of blocks
                %differently.
                switch blockType
                    case 'Goto'
                        %handles the case if the next block is a goto.
                        %Finds all froms and adds their outgoing ports to
                        %the list of ports to traverse
                        froms = findFromsInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(froms)
                            object.ReachedObjects(end + 1) = get_param(froms{j}, 'handle');
                            outport = get_param(froms{j}, 'PortHandles');
                            outport = outport.Outport;
                            if ~isempty(outport)
                                object.PortsToTraverse(end + 1) = outport;
                            end
                        end
                        %adds associated goto tag visibility block to the
                        %reach
                        tag=findVisibilityTag(getfullname(nextBlocks(i)));
                        if ~isempty(tag)
                            object.ReachedObjects(end+1)=get_param(tag, 'Handle');
                        end
                    case 'DataStoreWrite'
                        %handles the case if the next block is a data store
                        %write. Finds all data store reads and adds their
                        %outgoing ports to the list of ports to traverse
                        reads = findReadsInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(reads)
                            object.ReachedObjects(end + 1) = get_param(reads{j}, 'Handle');
                            outport = get_param(reads{j}, 'PortHandles');
                            outport = outport.Outport;
                            object.PortsToTraverse(end + 1) = outport;
                        end
                        %adds associated data store memory block to the
                        %reach
                        mem=findDataStoreMemory(getfullname(nextBlocks(i)));
                        if ~isempty(mem)
                            object.ReachedObjects(end+1)=get_param(mem, 'Handle');
                        end
                    case 'SubSystem'
                        %handles the case of the next block being a
                        %subsystem. Adds corresponding inports inside
                        %subsystem to reach and adds their outgoing ports
                        %to list of ports to traverse
                        dstPorts = get_param(line, 'DstPortHandle');
                        for j = 1:length(dstPorts)
                            portNum = get_param(dstPorts(j), 'PortNumber');
                            portType = get_param(dstPorts(j), 'PortType');
                            %this if statement checks for trigger, enable,
                            %or ifaction ports
                            if strcmp(portType, 'trigger')
                                object.reachEverythingInSub(getfullname(nextBlocks(i)));
                                triggerBlocks=find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
                                    'FollowLinks', 'on', 'BlockType', 'TriggerPort');
                                object.ReachedObjects(end + 1) =triggerBlocks;
                            elseif strcmp(portType, 'enable')
                                object.reachEverythingInSub(getfullname(nextBlocks(i)));
                                enableBlocks=find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
                                    'FollowLinks', 'on', 'BlockType', 'EnablePort');
                                object.ReachedObjects(end + 1) = enableBlocks;
                            elseif strcmp(portType, 'ifaction')
                                object.reachEverythingInSub(getfullname(nextBlocks(i)));
                                actionBlocks=find_system(nextBlocks(i), 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
                                    'FollowLinks', 'on', 'BlockType', 'ActionPort');
                                object.ReachedObjects(end + 1) = actionBlocks;
                            else
                                inport = find_system(nextBlocks(i), 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                                    'BlockType', 'Inport', 'Port', num2str(portNum));
                                object.ReachedObjects(end + 1) = get_param(inport, 'Handle');
                                outport = get_param(inport, 'PortHandles');
                                outport = outport.Outport;
                                object.PortsToTraverse(end + 1) = outport;
                            end
                        end
                    case 'Outport'
                        %handles the case where the next block is an
                        %outport. Provided the outport isn't at top level,
                        %add subsystem outport belongs to to the reach and
                        %add corresponding subsystem port of the outport to
                        %list of ports to traverse
                        portNum = get_param(nextBlocks(i), 'Port');
                        parent = get_param(nextBlocks(i), 'parent');
                        if ~isempty(get_param(parent, 'parent'))
                            portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                            object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                            object.PortsToTraverse(end + 1) = portSub;
                        end
                        
                    case {'WhileIterator', 'ForIterator'}
                        %get all blocks/ports in the subsystem, then reach
                        %the blocks the outports, gotos, and writes connect
                        %to outside of the system.
                        parent=get_param(block, 'parent');
                        object.reachEverythingInSub(parent);

                    case 'BusCreator'
                        %handles the case where the next block is a bus
                        %creator. follows the signal going into bus creator
                        %and highlights the path through the bused signal
                        %and out to its next block once the bus is
                        %separated.
                        signalName = get_param(line, 'Name');
                        if isempty(signalName)
                            dstPort = get_param(line, 'DstPortHandle');
                            portNum = get_param(dstPort, 'PortNumber');
                            signalName = ['signal' num2str(portNum)];
                        end
                        [~,path,blockList,exit] = object.traverseBusForwards(nextBlocks(i), signalName, [], []);
                        object.TraversedPorts = [object.TraversedPorts path];
                        object.ReachedObjects = [object.ReachedObjects blockList];
                        object.PortsToTraverse = [object.PortsToTraverse exit];
                    case 'If'
                        %handles the case where the next block is an if
                        %block, reaches each port where the corresponding
                        %condition is referenced and the else port
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        outports = ports.Outport;
                        dstPort = get_param(line, 'DstPortHandle');
                        portNum = get_param(dstPort, 'PortNumber');
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
                    otherwise
                        %otherwise case, simply adds outports of block to
                        %the list of ports to traverse
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        outports = ports.Outport;
                        for j = 1:length(outports)
                            object.PortsToTraverse(end + 1) = outports(j);
                        end                     
                end
            end
        end
        
        function coreach(object, port)
            % this function finds the next ports to find the coreach from,
            % and adds all objects encountered to coreached objects
                        
            %check if this port was already traversed
            if any(object.TraversedPortsCo==port)
                return
            end
            
            %get block port belongs to
            block = get_param(port, 'parent');
            
            %mark this port as traversed
            object.TraversedPortsCo(end + 1) = port;
            
            %get line from the port, and then get the destination blocks
            line = get_param(port, 'line');
            object.CoreachedObjects(end + 1) = line;
            nextBlocks = get_param(line, 'SrcBlockHandle');
            
            for i = 1:length(nextBlocks)
                %add block to list of coreached objects
                object.CoreachedObjects(end + 1) = nextBlocks(i);
                %get blocktype for switch case
                blockType = get_param(nextBlocks(i), 'BlockType');
                %switch statement that handles the coreaching of blocks
                %differently.
                switch blockType
                    case 'From'
                        %handles the case where the next block is a from
                        %block. finds all gotos associated with the from
                        %block, adds them to the coreach blocks, then adds their
                        %respective inports to the list of ports to
                        %traverse
                        gotos = findGotosInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(gotos)
                            object.CoreachedObjects(end + 1) = get_param(gotos{j}, 'handle');
                            inport = get_param(gotos{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        %adds associated goto tag visibility block to list
                        %of coreached objects
                        tag=findVisibilityTag(getfullname(nextBlocks(i)));
                        if ~isempty(tag)
                            object.CoreachedObjects(end+1)=get_param(tag, 'Handle');
                        end
                    case 'DataStoreRead'
                        %handles the case where the next block is a data
                        %store read block. finds all gotos associated with
                        %the write block, adds them to the coreached
                        %blocks, then adds their respective inports to the
                        %list of ports to traverse.
                        writes = findWritesInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(writes)
                            object.CoreachedObjects(end + 1) = get_param(writes{j}, 'Handle');
                            inport = get_param(writes{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        %adds associated data store memory block to the
                        %list of coreached objects.
                        mem=findDataStoreMemory(getfullname(nextBlocks(i)));
                        if ~isempty(mem)
                            object.CoreachedObjects(end+1)=get_param(mem, 'Handle');
                        end
                    case 'SubSystem'
                        %handles the case where the next block is a
                        %subsystem. Finds outport block corresponding to
                        %the outport of the subsystem, adds it to the
                        %list of coreached objects, then adds its inport to
                        %the list of inports to traverse.
                        srcPorts = get_param(line, 'SrcPortHandle');
                        for j = 1:length(srcPorts)
                            portNum = get_param(srcPorts(j), 'PortNumber');
                            outport = find_system(nextBlocks(i), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                            object.CoreachedObjects(end + 1) = get_param(outport, 'Handle');
                            inport = get_param(outport, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                    case 'Inport'
                        %handles the case where the next block is an
                        %inport. If the inport is not top level, it adds
                        %the parent subsystem to the list of coreached
                        %objects, then adds the corresponding inport on the
                        %subsystem to the list of ports to traverse.
                        portNum = get_param(nextBlocks(i), 'Port');
                        parent = get_param(nextBlocks(i), 'parent');
                        if ~isempty(get_param(parent, 'parent'))
                            portSub = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2num(portNum));
                            object.CoreachedObjects(end + 1) = get_param(parent, 'handle');
                            object.PortsToTraverseCo(end + 1) = portSub;
                        end
                    case 'BusSelector'
                        %handles the case where the next block is a bus
                        %selector. follows the signal going into the bus
                        %and adds the path through the bus to the list of
                        %coreached objects. Adds the corresponding exit
                        %port on the bus creator to the list of ports to
                        %traverse.
                        portBus=get_param(line, 'SrcPortHandle');
                        portNum=get_param(portBus, 'PortNumber');
                        signal=get_param(nextBlocks(i), 'OutputSignals');
                        signal=regexp(signal, ',', 'split');
                        signal = signal{portNum};
                        [~, path, blockList, exit]=object.traverseBusBackwards(nextBlocks(i), signal, [], []);
                        object.TraversedPortsCo=[object.TraversedPortsCo path];
                        object.CoreachedObjects=[object.CoreachedObjects blockList];
                        object.PortsToTraverseCo(end+1)=exit;
                    case 'If'
                        %handles the case where the next block is an if
                        %block. Adds ports with conditions corresponding to
                        %the conditions associated with teh outport the
                        %current port leads into to the list of ports to
                        %traverse.
                        srcPort = get_param(line, 'SrcPortHandle');
                        portNum = get_param(srcPort, 'PortNumber');
                        expressions = get_param(nextBlocks(i), 'ElseIfExpressions');
                        if ~isempty(expressions)
                            expressions = regexp(expressions, ',', 'split');
                            expressions = [{get_param(nextBlocks(i), 'IfExpression')} expressions];
                        else
                            expressions = {};
                            expressions{end + 1} = get_param(nextBlocks(i), 'IfExpression');
                        end
                        if portNum>length(expressions)
                            %else case
                            ifPorts=get_param(nextBlocks(i), 'PortHandles');
                            ifPorts=ifPorts.Inport;
                            object.PortsToTraverseCo=[object.PortsToTraverseCo ifPorts];
                        else
                            conditions = regexp(expressions{portNum}, 'u[1-9]+', 'match');
                            for j=1:length(conditions)
                                cond=conditions{j};
                                cond = cond(2:end);
                                ifPorts=get_param(nextBlocks(i), 'PortHandles');
                                ifPorts=ifPorts.Inport;
                                object.PortsToTraverseCo(end+1)=ifPorts(str2num(cond));
                            end
                        end
                    otherwise
                        %otherwise case, simply adds the inports of the block
                        %to the list of ports to traverse.
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        inports = ports.Inport;
                        for j = 1:length(inports)
                            object.PortsToTraverseCo(end + 1) = inports(j);
                        end    
                end
            end
        end
        
        function iterators = findIterators(object)
        % Function finds all while and for iterators that need to be
        % coreached.
            iterators = {};
            candidates = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'WhileIterator');
            candidates = [candidates find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ForIterator')];
            for i = 1:length(candidates)
                system = get_param(candidates{i}, 'parent');
                sysObjects = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects=setdiff(sysObjects, system);
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(candidates{i}, 'Handle'), object.CoreachedObjects))
                        iterators{end + 1} = candidates{i};
                    end
                end
            end
        end
        
        function findSpecialPorts(object)
            %function finds all actionport, foreach, triggerport, and enableport
            %blocks and adds them to the coreach, as well as adding their
            %corresponding port in the parent subsystem block to the list
            %of ports to traverse.
            actionPorts=find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ActionPort');
            for i=1:length(actionPorts)
                system=get_param(actionPorts{i}, 'parent');
                sysObjects=find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects=setdiff(sysObjects, get_param(system, 'handle'));
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(actionPorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(actionPorts{i}, 'Handle');
                        sysPorts=get_param(system, 'PortHandles');
                        object.PortsToTraverseCo=[object.PortsToTraverseCo sysPorts.Ifaction];
                    end
                end
            end
            
            triggerPorts=find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'TriggerPort');
            for i=1:length(triggerPorts)
                system=get_param(triggerPorts{i}, 'parent');
                sysObjects=find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects=setdiff(sysObjects, get_param(system, 'handle'));
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(triggerPorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(triggerPorts{i}, 'Handle');
                        sysPorts=get_param(system, 'PortHandles');
                        object.PortsToTraverseCo=[object.PortsToTraverseCo sysPorts.Trigger];
                    end
                end
            end
            
            enablePorts=find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'EnablePort');
            for i=1:length(enablePorts)
                system=get_param(enablePorts{i}, 'parent');
                sysObjects=find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects=setdiff(sysObjects, get_param(system, 'handle'));
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(enablePorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(enablePorts{i}, 'Handle');
                        sysPorts=get_param(system, 'PortHandles');
                        object.PortsToTraverseCo=[object.PortsToTraverseCo sysPorts.Enable];
                    end
                end
            end
            
            forEach=find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ForEach');
            for i=1:length(forEach)
                system=get_param(forEach{i}, 'parent');
                sysObjects=find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on');
                sysObjects=setdiff(sysObjects, get_param(system, 'handle'));
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(forEach{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(forEach{i}, 'Handle');
                    end
                end
            end
        end
                
        
        function reachEverythingInSub(object, system)
            %adds all blocks and outports of blocks in the subsystem to the lists of reached
            %objects. Additionally, finds all interface going outward
            %(outports, gotos, froms) and finds the next blocks/ports as if
            %being reached by the main reach function above.
            blocks = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on');
            
            %excludes trigger, enable, and action port blocks (they're
            %added in main function)
            blocksToExclude=find_system(system, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'EnablePort');
            blocksToExclude=[blocksToExclude find_system(system, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'TriggerPort')];
            blocksToExclude=[blocksToExclude find_system(system, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'ActionPort')];
            blocks=setdiff(blocks, blocksToExclude);
            
            for i=1:length(blocks)
                object.ReachedObjects(end+1)=get_param(blocks{i}, 'handle');
            end
            lines = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'line');
            object.ReachedObjects=[object.ReachedObjects lines.'];
            ports = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'port');
            portsToExclude=get_param(system, 'PortHandles');
            portsToExclude=portsToExclude.Outport;
            ports=setdiff(ports, portsToExclude);
            object.TraversedPorts = [object.TraversedPorts ports.'];
            
            %handles outports same as the reach function
            outports = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'BlockType', 'Outport');
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
            
            %handles gotos same as the reach function
            gotos = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto');
            for j = 1:length(gotos)
                froms = findFromsInScope(gotos{j});
                for k = 1:length(froms)
                    object.ReachedObjects(end + 1) = get_param(froms{k}, 'handle');
                    outport = get_param(froms{k}, 'PortHandles');
                    outport = outport.Outport;
                    object.PortsToTraverse(end + 1) = outport;
                end
                tag=findVisibilityTag(gotos{j});
                object.ReachedObjects(end+1)=get_param(tag, 'Handle');
            end
            
            %handles writes same as the reach function
            writes = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite');
            for j = 1:length(writes)
                reads = findReadsInScope(writes{j});
                for k = 1:length(reads)
                    object.ReachedObjects(end + 1) = get_param(reads{k}, 'Handle');
                    outport = get_param(reads{k}, 'PortHandles');
                    outport = outport.Outport;
                    object.PortsToTraverse(end + 1) = outport;
                end
                mem=findDataStoreMemory(writes{j});
                object.ReachedObjects(end+1)=get_param(mem, 'Handle');
            end
        end
        
        function blocks=getInterfaceIn(object, subsystem)
            %get all the source blocks for the subsystem, including gotos
            %and data store writes
            blocks={};
            gotos={};
            writes={};
            froms=find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'From');
            for i=1:length(froms)
                gotos=findFromsInScope(froms{i});
            end
            reads=find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreRead');
            for i=1:length(reads)
                writes=findReadsInScope(reads{i});
            end
            implicits=[gotos writes];
            for i=1:length(implicits)
                name=getfullname(implicits{i});
                lcs=intersect(name, getfullname(subsystem));
                if ~strcmp(lcs, getfullname(subsystem))
                    blocks{end+1}=implicits{i};
                end
            end
        end
        
        function blocks=getInterfaceOut(object, subsystem)
            %get all the destination blocks for the subsystem, including
            %froms and data store reads
            blocks={};
            froms={};
            reads={};
            gotos=find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Goto');
            for i=1:length(gotos)
                froms=findFromsInScope(gotos{i});
            end
            writes=find_system(subsystem, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite');
            for i=1:length(writes)
                reads=findReadsInScope(writes{i});
            end
            implicits=[froms reads];
            for i=1:length(implicits)
                name=getfullname(implicits{i});
                lcs=intersect(name, getfullname(subsystem));
                if ~strcmp(lcs, getfullname(subsystem))
                    blocks{end+1}=implicits{i};
                end
            end
        end
        
        function [dest, path, blockList, exit]=traverseBusForwards(object, block, signal, path, blockList)
            %go until you hit a bus creator, then return the path taken there as
            %well as the exiting port
            for g=1:length(block)
                blockList(end+1)=get_param(block(g), 'Handle');
                portConnectivity=get_param(block(g), 'PortConnectivity');
                dstBlocks=portConnectivity(end).DstBlock;
                %if the bus ends early (not at bus selector) output empty
                %dest and exit
                if isempty(dstBlocks)
                    dest=[];
                    exit=[];
                end
                %for each of the destination blocks
                for h=1:length(dstBlocks)
                    next=dstBlocks(h);
                    portHandles=get_param(block(g), 'PortHandles');
                    port=portHandles.Outport;
                    path(end+1)=port;
                    portline=get_param(port, 'line');
                    blockList(end+1)=portline;
                    blockType=get_param(next, 'BlockType');
                    switch blockType
                        case 'BusCreator'
                            %if next block is bus creator, call the
                            %traverse function recursively.
                            blockLines=get_param(block(g), 'LineHandles');
                            blockLines=blockLines.Outport;
                            nextLines=get_param(next, 'LineHandles');
                            nextLines=nextLines.Inport;
                            line=intersect(blockLines, nextLines);
                            line=intersect(line, portline);
                            signalName=get_param(line, 'Name');
                            if ~isempty(signalName)
                                dstPort=get_param(line, 'DstPortHandle');
                                portNum=get_param(dstPort, 'PortNumber');
                                signalName=['signal' num2str(portNum)];
                                [intermediate,path,blockList,exit]=object.traverseBusForwards(get_param(next, 'handle'), ...
                                    signalName, path, blockList);
                                path=[path exit];
                                dest=[];
                                exit=[];
                                for i=1:length(intermediate)
                                    [tempDest, tempPath, tempBlockList, tempExit]=object.traverseBusForwards(get_param(intermediate(i), 'handle'), ...
                                        signal, path, blockList);
                                    dest=[dest tempDest];
                                    exit=[exit tempExit];
                                    blockList=[blockList tempBlockList];
                                    path=[path, tempPath];
                                end
                            else
                                [intermediate, path, blockList, ~]=object.traverseBusForwards(get_param(next, 'handle'), ...
                                    signalName, path, blockList);
                                dest=[];
                                exit=[];
                                for i=1:length(intermediate)
                                    [tempDest, tempPath, tempBlockList, tempExit]=object.traverseBusForwards(get_param(intermediate(i), 'handle'), ...
                                        signal, path, blockList);
                                    dest=[dest tempDest];
                                    exit=[exit tempExit];
                                    blockList=[blockList tempBlockList];
                                    path=[path, tempPath];
                                end
                            end
                        case 'BusSelector'
                            %base case for recursion, get the exiting
                            %port from the bus selector and pass out all
                            %other relevant information
                            blockList(end+1)=get_param(next ,'handle');
                            outputs=get_param(next, 'OutputSignals');
                            outputs=regexp(outputs, ',', 'split');
                            portNum=find(strcmp(outputs(:), signal));
                            if ~isempty(portNum)
                                dest=get_param(next, 'PortConnectivity');
                                dest=dest(1+portNum).DstBlock;
                                exit=get_param(next, 'PortHandles');
                                exit=exit.Outport;
                                exit=exit(portNum);
                            else
                                dest=[];
                                exit=[];
                            end
                        case 'Goto'
                            %follow bused signal through goto
                            blockList(end+1)=get_param(next ,'handle');
                            froms=findFromsInScope(next);
                            dest=[];
                            exit=[];
                            for i=1:length(froms)
                                [tempDest, tempPath, tempBlockList, tempExit]=object.traverseBusForwards(get_param(froms{i}, 'handle'), ...
                                    signal, path, blockList);
                                dest=[dest tempDest];
                                exit=[exit tempExit];
                                blockList=[blockList tempBlockList];
                                path=[path, tempPath];
                                tag=findVisibilityTag(froms{i});
                                if~isempty(tag)
                                    blockList(end+1)=get_param(tag, 'Handle');
                                end
                            end
                        case 'SubSystem'
                            %follow bused signal into subsystem
                            blockList(end+1)=get_param(next ,'handle');
                            blockLines=get_param(block(g), 'LineHandles');
                            blockLines=blockLines.Outport;
                            nextLines=get_param(next, 'LineHandles');
                            nextLines=nextLines.Inport;
                            line=intersect(blockLines, nextLines);
                            line=intersect(line, portline);
                            blockList(end+1)=line;
                            dstPorts=get_param(line, 'DstPortHandle');
                            for j=1:length(dstPorts)
                                portNum=get_param(dstPorts(j), 'PortNumber');
                                inport=find_system(next, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Inport', 'Port', num2str(portNum));
                                [dest, path, blockList, exit]=object.traverseBusForwards(get_param(inport, 'handle'), ...
                                    signal, path, blockList);
                            end
                        case 'Outport'
                            %follow bused signal out of subsystem
                            blockList(end+1)=get_param(next ,'handle');
                            portNum=get_param(next, 'Port');
                            parent=get_param(next, 'parent');
                            if ~isempty(get_param(parent, 'parent'))
                                blockList(end+1)=get_param(parent, 'Handle');
                                port=find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                                    'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                                path(end+1)=port;
                                connectedBlock=get_param(get_param(port, 'line'), 'DstBlockHandle');
                                [dest, path, blockList, exit]=object.traverseBusForwards(get_param(connectedBlock, 'handle'), ...
                                    signal, path, blockList);
                            else
                                dest=[];
                                exit=[];
                            end
                        case 'BusToVector'
                            blockList(end+1)=get_param(next ,'handle');
                            exit=get_param(next, 'PortHandles');
                            exit=exit.Outport;
                            dest=[];
                        otherwise
                            [dest, path, blockList, exit]=object.traverseBusForwards(get_param(next, 'handle'), ...
                                signal, path, blockList);
                    end
                end
            end
        end
        
        function [dest, path, blockList, exit]=traverseBusBackwards(object, block, signal, path, blockList)
            %go until you hit a bus creator, then return the path taken there as
            %well as the exiting port
            blockList(end+1)=get_param(block, 'Handle');
            portConnectivity=get_param(block, 'PortConnectivity');
            srcBlocks=portConnectivity(1).SrcBlock;
            if isempty(srcBlocks)
                dest=[];
                exit=[];
                return
            end
            next=srcBlocks(1);
            portHandles=get_param(block, 'PortHandles');
            port=portHandles.Inport;
            path(end+1)=port;
            portLine=get_param(port, 'line');
            blockList(end+1)=portLine;
            blockType=get_param(next, 'BlockType');
            %if the bus ends early (not at bus selector) output empty
            %dest and exit
            switch blockType
                case 'BusSelector'
                    % if another bus selector is encountered, call the
                    % function recursively
                    [intermediate,path,blockList,exit]=object.traverseBusBackwards(get_param(next, 'handle'), ...
                        signal, path, blockList);
                    path=[path exit];
                    dest=[];
                    exit=[];
                    for i=1:length(intermediate)
                        [tempDest, tempPath, tempBlockList, tempExit]=object.traverseBusBackwards(get_param(intermediate(i), 'handle'), ...
                            signal, path, blockList);
                        dest=[dest tempDest];
                        exit=[exit tempExit];
                        blockList=[blockList tempBlockList];
                        path=[path, tempPath];
                    end
                case 'BusCreator'
                    %case where the exit of the current bused signal is
                    %found
                    blockList(end+1)=next;
                    inputs=get_param(next, 'LineHandles');
                    inputs=inputs.Inport;
                    inputs=get_param(inputs, 'Name');
                    portNum=find(strcmp(signal, inputs));
                    if isempty(portNum)
                        portNum=regexp(signal, '[1-9]*$', 'match');
                        portNum=str2num(portNum{1});
                    end
                    dest=get_param(next, 'PortConnectivity');
                    dest=dest(1+portNum).SrcBlock;
                    exit=get_param(next, 'PortHandles');
                    exit=exit.Inport;
                    exit=exit(portNum);
                case 'From'
                    %follow the bus through the from blocks
                    blockList(end+1)=next;
                    gotos=findGotosInScope(next);
                    dest=[];
                    exit=[];
                    for i=1:length(gotos)
                        [tempDest, tempPath, tempBlockList, tempExit]=object.traverseBusBackwards(get_param(gotos{i}, 'handle'), ...
                            signal, path, blockList);
                        dest=[dest tempDest];
                        exit=[exit tempExit];
                        blockList=[blockList tempBlockList];
                        path=[path, tempPath];
                        tag=findVisibilityTag(gotos{i});
                        if~isempty(tag)
                            blockList(end+1)=get_param(tag, 'Handle');
                        end
                    end
                case 'SubSystem'
                    %follow the bus into a subsystem
                    blockList(end+1)=next;
                    blockLines=get_param(block, 'LineHandles');
                    nextLines=get_param(next, 'LineHandles');
                    line=intersect(blockLines, nextLines);
                    blockList(end+1)=line;
                    srcPorts=get_param(line, 'SrcPortHandle');
                    for j=1:length(srcPorts)
                        portNum=get_param(srcPorts(j), 'PortNumber');
                        inport=find_system(next, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                        [dest, path, blockList, exit]=object.traverseBusBackwards(get_param(inport, 'handle'), signal, path, blockList);
                    end
                case 'Inport'
                    %follow the bus out of the subsystem or end
                    portNum=get_param(next, 'Port');
                    parent=get_param(next, 'parent');
                    if isempty(get_param(parent, 'parent'))
                        blockList(end+1)=get_param(parent, 'Handle');
                        port=find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                            'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2num(portNum));
                        path(end+1)=port;
                        connectedBlock=get_param(get_param(port, 'line'), 'SrcBlockHandle');
                        [dest, path, blockList, exit]=object.traverseBusBackwards(get_param(connectedBlock, 'handle'), signal, path, blockList);
                    else
                        dest=[];
                        exit=[];
                        blockList(end+1)=next;
                    end
                otherwise
                    [dest, path, blockList, exit]=object.traverseBusBackwards(get_param(next, 'handle'), signal, path, blockList);
            end
        end
    end
end
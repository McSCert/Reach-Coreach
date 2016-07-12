classdef ReachCoreach < handle
%REACHCOREACH Summary of this function goes here.
%   Detailed explanation goes here.

    properties
        RootSystemName      % Simulink model name (or top-level system name)
        
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
            % Initialize a new instance of ReachCoreach.
            object.RootSystemName = RootSystemName;
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            HILITE_DATA=struct('HiliteType', 'user2', 'ForegroundColor', 'red', 'BackgroundColor', 'yellow');
            set_param(0, 'HiliteAncestorsData', HILITE_DATA);
        end
        
        function setColor(object, color1, color2)
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
            % Isolate the  reached/coreached blocks.
            allObjects = find_system(object.RootSystemName, 'FindAll', 'On', 'type', 'line');
            allObjects = [allObjects find_system(object.RootSystemName, 'FindAll', 'On', 'type', 'block')];
            toDelete = setdiff(allObjects, object.ReachedObjects);
            delete_block(toDelete);
        end
        
        function clear(object)
            % Remove the reached/coreached blocks from selection.
            hilite_system(object.ReachedObjects, 'none');
            hilite_system(object.CoreachedObjects, 'none');
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            object.TraversedPorts=[];
            object.TraversedPortsCo=[];
        end
        
        function reachAll(object, selection)
            % Public function to reach from all of a selection of blocks.
                        
            % Get the ports/blocks of selected blocks that are special
            % cases
            for i = 1:length(selection)
                selectionType=get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    %get all outgoing interface from subsystem, and add
                    %blocks to reach, as well as ports to the list of ports
                    %to traverse
                    outBlocks=getInterfaceOut(selection{i});
                    for j=1:length(outBlocks)
                        object.ReachedObjects(end + 1) = get_param(outBlocks{j}, 'handle');
                        ports = get_param(outBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
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
                    object.ReachedObjects(end+1)=get_param(mem, 'Handle');
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
                    object.ReachedObjects(end+1)=get_param(tag, 'Handle');
                elseif (strcmp(selectionType, 'EnablePort') || ...
                        strcmp(selectionType, 'ActionPort') || ...
                        strcmp(selectionType, 'TriggerPort') || ...
                        strcmp(selectionType, 'WhileIterator') || ...
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
            
            % Get the ports/blocks of selected blocks that are special
            % cases
            for i = 1:length(selection)
                selectionType=get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    %get all incoming interface to subsystem, and add
                    %blocks to coreach, as well as ports to the list of ports
                    %to traverse
                    inBlocks=getInterfaceIn(selection{i});
                    for j=1:length(inBlocks)
                        object.CoreachedObjects(end + 1) = get_param(inBlocks{j}, 'handle');
                        ports = get_param(inBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
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
                    object.CoreachedObjects(end+1)=get_param(tag, 'Handle');
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
                    object.CoreachedObjects(end+1)=get_param(mem, 'Handle');
                end
                %add blocks to coreach from selection, and their ports to the
                %list to traverse
                object.CoreachedObjects(end + 1) = get_param(selection{i}, 'handle');
                ports = get_param(selection{i}, 'PortHandles');
                object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
            end
            flag=true;
            while flag
                %coreach from each in the list of ports to traverse
                while ~isempty(object.PortsToTraverseCo)
                    port = object.PortsToTraverseCo(end);
                    object.PortsToTraverseCo(end) = [];
                    coreach(object, port)
                end
                object.hiliteObjects();
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
                        %subsystem. Adds
                        dstPorts = get_param(line, 'DstPortHandle');
                        for j = 1:length(dstPorts)
                            portNum = get_param(dstPorts(j), 'PortNumber');
                            portType = get_param(dstPorts(j), 'PortType');
                            if (strcmp(portType, 'trigger') || ...
                                    strcmp(portType, 'enable') || ...
                                    strcmp(portType, 'ifaction'))
                                object.reachEverythingInSub(getfullname(nextBlocks(i)));
                            else
                                inport = find_system(nextBlocks(i), 'BlockType', 'Inport', 'Port', num2str(portNum));
                                object.ReachedObjects(end + 1) = get_param(inport, 'Handle');
                                outport = get_param(inport, 'PortHandles');
                                outport = outport.Outport;
                                object.PortsToTraverse(end + 1) = outport;
                            end
                        end
                    case 'Outport'
                        portNum = get_param(nextBlocks(i), 'Port');
                        parent = get_param(nextBlocks(i), 'parent');
                        if ~isempty(get_param(parent, 'parent'))
                            port = find_system(get_param(parent, 'parent'), 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                            object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                            object.PortsToTraverse(end + 1) = port;
                        end
                        
                    case {'WhileIterator', 'ForIterator'}
                        %get all blocks/ports in the subsystem, then reach
                        %the blocks the outports, gotos, and writes connect
                        %to outside of the system.
                        parent=get_param(block, 'parent');
                        object.reachEverythingInSub(parent);

                    case 'BusCreator'
                        signalName = get_param(line, 'Name');
                        if isempty(signalName)
                            dstPort = get_param(line, 'DstPortHandle');
                            portNum = get_param(dstPort, 'PortNumber');
                            signalName = ['signal' num2str(portNum)];
                        end
                        [~,path,blockList,exit] = traverseBusForwards(nextBlocks(i), signalName, [], []);
                        object.TraversedPorts = [object.TraversedPorts path];
                        object.ReachedObjects = [object.ReachedObjects blockList];
                        object.PortsToTraverse = [object.PortsToTraverse exit];
                    case 'If'
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
                        ports = get_param(nextBlocks(i), 'PortHandles');
                        outports = ports.Outport;
                        for j = 1:length(outports)
                            object.PortsToTraverse(end + 1) = outports(j);
                        end                     
                end
            end
        end
        
        function coreach(object, port)
            % TODO Description.
                        
            %check if this port was already traversed
            if isempty(setdiff(port, object.TraversedPortsCo))
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
                %switch statement that handles the reaching of blocks
                %differently.
                switch blockType
                    case 'From'
                        gotos = findGotosInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(gotos)
                            object.CoreachedObjects(end + 1) = get_param(gotos{j}, 'handle');
                            inport = get_param(gotos{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        tag=findVisibilityTag(getfullname(nextBlocks(i)));
                        if ~isempty(tag)
                            object.CoreachedObjects(end+1)=get_param(tag, 'Handle');
                        end
                    case 'DataStoreRead'
                        writes = findWritesInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(writes)
                            object.CoreachedObjects(end + 1) = get_param(writes{j}, 'Handle');
                            inport = get_param(writes{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        mem=findDataStoreMemory(getfullname(nextBlocks(i)));
                        if ~isempty(mem)
                            object.CoreachedObjects(end+1)=get_param(mem, 'Handle');
                        end
                    case 'SubSystem'
                        srcPorts = get_param(line, 'SrcPortHandle');
                        for j = 1:length(srcPorts)
                            portNum = get_param(srcPorts(j), 'PortNumber');
                            outport = find_system(nextBlocks(i), 'BlockType', 'Outport', 'Port', num2str(portNum));
                            object.CoreachedObjects(end + 1) = get_param(outport, 'Handle');
                            inport = get_param(outport, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                    case 'Inport'
                        portNum = get_param(nextBlocks(i), 'Port');
                        parent = get_param(nextBlocks(i), 'parent');
                        if ~isempty(get_param(parent, 'parent'))
                            portSub = find_system(get_param(parent, 'parent'), 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2num(portNum));
                            object.CoreachedObjects(end + 1) = get_param(parent, 'handle');
                            object.PortsToTraverseCo(end + 1) = portSub;
                        end
                    case 'BusSelector'
                        portBus=get_param(line, 'SrcPortHandle');
                        portNum=get_param(portBus, 'PortNumber');
                        signal=get_param(nextBlocks(i), 'OutputSignals');
                        signal=regexp(signal, ',', 'split');
                        signal = signal{portNum};
                        [~, path, blockList, exit]=traverseBusBackwards(nextBlocks(i), signal, [], []);
                        object.TraversedPortsCo=[object.TraversedPortsCo path];
                        object.CoreachedObjects=[object.CoreachedObjects blockList];
                        object.PortsToTraverseCo(end+1)=exit;
                    case 'If'
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
            candidates = find_system(object.RootSystemName, 'BlockType', 'WhileIterator');
            candidates = [candidates find_system(object.RootSystemName, 'BlockType', 'ForIterator')];
            for i = 1:length(candidates)
                system = get_param(candidates{i}, 'parent');
                sysObjects = find_system(system, 'FindAll', 'on');
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(candidates{i}, 'Handle'), object.CoreachedObjects))
                        iterators{end + 1} = candidates{i};
                    end
                end
            end
        end
        
        function findSpecialPorts(object)
            actionPorts=find_system(object.RootSystemName, 'BlockType', 'ActionPort');
            for i=1:length(actionPorts)
                system=get_param(actionPorts{i}, 'parent');
                sysObjects=find_system(system, 'FindAll', 'on');
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(actionPorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(actionPorts{i}, 'Handle');
                        sysPorts=get_param(system, 'PortHandles');
                        object.PortsToTraverseCo=[object.PortsToTraverseCo sysPorts.Ifaction];
                    end
                end
            end
            
            triggerPorts=find_system(object.RootSystemName, 'BlockType', 'TriggerPort');
            for i=1:length(triggerPorts)
                system=get_param(triggerPorts{i}, 'parent');
                sysObjects=find_system(system, 'FindAll', 'on');
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(triggerPorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(triggerPorts{i}, 'Handle');
                        sysPorts=get_param(system, 'PortHandles');
                        object.PortsToTraverseCo=[object.PortsToTraverseCo sysPorts.Trigger];
                    end
                end
            end
            
            enablePorts=find_system(object.RootSystemName, 'BlockType', 'EnablePort');
            for i=1:length(enablePorts)
                system=get_param(enablePorts{i}, 'parent');
                sysObjects=find_system(system, 'FindAll', 'on');
                if ~isempty(intersect(sysObjects, object.CoreachedObjects))
                    if isempty(intersect(get_param(enablePorts{i}, 'Handle'), object.CoreachedObjects))
                        object.CoreachedObjects(end + 1) = get_param(enablePorts{i}, 'Handle');
                        sysPorts=get_param(system, 'PortHandles');
                        object.PortsToTraverseCo=[object.PortsToTraverseCo sysPorts.Enable];
                    end
                end
            end
        end
                
        
        function reachEverythingInSub(object, system)
            blocks = find_system(system, 'LookUnderMasks', 'all', 'FollowLinks', 'on');
            for i=1:length(blocks)
                object.ReachedObjects(end+1)=get_param(blocks{i}, 'handle');
            end
            ports = find_system(system, 'FindAll', 'on', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'type', 'port');
            portsToExclude=get_param(system, 'PortHandles');
            portsToExclude=portsToExclude.Outport;
            ports=setdiff(ports, portsToExclude);
            object.TraversedPorts = [object.TraversedPorts ports.'];
            outports = find_system(system, 'SearchDepth', 1, 'BlockType', 'Outport');
            for j = 1:length(outports)
                portNum = get_param(outports{j}, 'Port');
                parent = get_param(outports{j}, 'parent');
                if ~isempty(get_param(parent, 'parent'))
                    port = find_system(get_param(parent, 'parent'), 'SearchDepth', 1, 'FindAll', 'on', ...
                        'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                    object.ReachedObjects(end + 1) = get_param(parent, 'handle');
                    object.PortsToTraverse(end + 1) = port;
                end
            end
            gotos = find_system(system, 'BlockType', 'Goto');
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
            writes = find_system(system, 'BlockType', 'DataStoreWrite');
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
    end
end
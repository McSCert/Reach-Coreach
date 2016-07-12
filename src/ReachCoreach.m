classdef ReachCoreach < handle
%REACHCOREACH Summary of this function goes here.
%   Detailed explanation goes here.

    properties
        RootSystemName      % Simulink model name (or top-level system name)
        
        ReachedObjects      % List of blocks and lines reached
        CoreachedObjects    % List of blocks and lines coreached
        
        PortsToTraverse     % Ports remaining to traverse in reach operation
        PortsToTraverseCo   % Ports remaining to traverse in coreach operation
        
        TraversedPorts      % Ports already traversed in reach operation
        TraversedPortsCo    % Ports already traversed in coreach operation
    end
    
    methods
        
        function object = ReachCoreach(RootSystemName)
            % Initialize a new instance of ReachCoreach.
            object.RootSystemName = RootSystemName;
            object.ReachedObjects = [];
            object.CoreachedObjects = [];
            HILITE_DATA=struct('HiliteType', 'user2', 'ForegroundColor', 'yellow', 'BackgroundColor', 'red');
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
            % TODO Description.
                        
            % Get all the outports from the selected blocks
            for i = 1:length(selection)
                selectionType=get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    outBlocks=getInterfaceOut(selection{i});
                    for j=1:length(outBlocks)
                        object.ReachedObjects(end + 1) = get_param(outBlocks{j}, 'handle');
                        ports = get_param(outBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                elseif strcmp(selectionType, 'GotoTagVisibility')
                    associatedBlocks=findGotoFromsInScope(selection{i});
                    for j=1:length(associatedBlocks)
                        object.ReachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                elseif strcmp(selectionType, 'DataStoreMemory')
                    associatedBlocks=findReadWritesInScope(selection{i});
                    for j=1:length(associatedBlocks)
                        object.ReachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverse = [object.PortsToTraverse ports.Outport];
                    end
                end
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
            object.hiliteObjects();
        end
        
        function coreachAll(object, selection)
            % TODO Description.
            
            for i = 1:length(selection)
                selectionType=get_param(selection{i}, 'BlockType');
                if strcmp(selectionType, 'SubSystem')
                    inBlocks=getInterfaceIn(selection{i});
                    for j=1:length(inBlocks)
                        object.CoreachedObjects(end + 1) = get_param(inBlocks{j}, 'handle');
                        ports = get_param(inBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                    elseif strcmp(selectionType, 'GotoTagVisibility')
                        associatedBlocks=findGotoFromsInScope(selection{i});
                        for j=1:length(associatedBlocks)
                            object.CoreachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                            ports = get_param(associatedBlocks{j}, 'PortHandles');
                            object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                        end
                elseif strcmp(selectionType, 'DataStoreMemory')
                    associatedBlocks=findReadWritesInScope(selection{i});
                    for j=1:length(associatedBlocks)
                        object.CoreachedObjects(end + 1) = get_param(associatedBlocks{j}, 'handle');
                        ports = get_param(associatedBlocks{j}, 'PortHandles');
                        object.PortsToTraverseCo = [object.PortsToTraverseCo ports.Inport];
                    end
                end
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
                iterators=findIterators(object);
                if ~isempty(iterators);
                    for i=1:length(iterators)
                        ports=get_param(iterators{i}, 'PortHandles');
                        object.PortsToTraverseCo=[object.PortsToTraverseCo, ports.Inport];
                        object.CoreachedObjects(end+1)=get_param(iterators{i}, 'Handle');
                    end
                else
                    flag=false;
                end
            end
        end
        
        function reach(object, port)
            % TODO Description.
            
            % check if this port was already traversed
            if isempty(setdiff(port, object.TraversedPorts))
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
                        froms = findFromsInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(froms)
                            object.ReachedObjects(end + 1) = get_param(froms{j}, 'handle');
                            outport = get_param(froms{j}, 'PortHandles');
                            outport = outport.Outport;
                            if ~isempty(outport)
                                object.PortsToTraverse(end + 1) = outport;
                            end
                        end
                        tag=findVisibilityTag(getfullname(nextBlocks(i)));
                        object.ReachedObjects(end+1)=get_param(tag, 'Handle');
                    case 'DataStoreWrite'
                        reads = findReadsInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(reads)
                            object.ReachedObjects(end + 1) = get_param(reads{j}, 'Handle');
                            outport = get_param(reads{j}, 'PortHandles');
                            outport = outport.Outport;
                            object.PortsToTraverse(end + 1) = outport;
                        end
                        mem=findDataStoreMemory(getfullname(nextBlocks(i)));
                        object.ReachedObjects(end+1)=get_param(mem, 'Handle');
                    case 'SubSystem'
                        dstPorts = get_param(line, 'DstPortHandle');
                        for j = 1:length(dstPorts)
                            portNum = get_param(dstPorts(j), 'PortNumber');
                            inport = find_system(nextBlocks(i), 'BlockType', 'Inport', 'Port', num2str(portNum));
                            object.ReachedObjects(end + 1) = get_param(inport, 'Handle');
                            outport = get_param(inport, 'PortHandles');
                            outport = outport.Outport;
                            object.PortsToTraverse(end + 1) = outport;
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
                        blocks = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                        object.ReachedObjects = [object.ReachedObjects get_param(blocks, 'Handle')];
                        ports = find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                        object.TraversedPorts = [object.TraversedPorts ports];
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
                        object.CoreachedObjects(end+1)=get_param(tag, 'Handle');
                    case 'DataStoreRead'
                        writes = findWritesInScope(getfullname(nextBlocks(i)));
                        for j = 1:length(writes)
                            object.CoreachedObjects(end + 1) = get_param(writes{j}, 'Handle');
                            inport = get_param(writes{j}, 'PortHandles');
                            inport = inport.Inport;
                            object.PortsToTraverseCo(end + 1) = inport;
                        end
                        mem=findDataStoreMemory(getfullname(nextBlocks(i)));
                        object.CoreachedObjects(end+1)=get_param(mem, 'Handle');
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
                        else
                            conditions = regexp(expressions{portNum}, 'u[1-9] + ', 'match');
                            cond = conditions{portNum};
                            cond = cond(2:end);
                            port = find_system(get_param(nextBlocks(i), 'parent'), 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', nextBlocks(i), 'PortType', 'Inport', 'PortNumber', str2num(cond));
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
        % TODO Description.
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
    end
end
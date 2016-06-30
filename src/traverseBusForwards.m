function [dest, path, blockList, exit]=traverseBusForwards(block, signal, path, blockList)
    %go until you hit a bus creator, then return the path taken there as
    %well as the exiting port
    blockList(end+1)=block;
    portConnectivity=get_param(block, 'PortConnectivity');
    dstBlocks=portConnectivity(end).DstBlock;
    next=dstBlocks(1);
    portHandles=get_param(block, 'PortHandles');
    path(end+1)=portHandles.Outport;
    blockType=get_param(next, 'BlockType');
    switch blockType
        case 'BusCreator'
            blockLines=get_param(block, 'LineHandles');
            nextLines=get_param(next, 'LineHandles');
            line=intersect(blockLines, nextLines);
            signalName=get_param(line, 'Name');
            if ~isempty(signalName)
                dstPort=get_param(line, 'DstPortHandle');
                portNum=get_param(dstPort, 'PortNumber');
                signalName=['signal' num2str(portNum)];
                intermediate=traverseBusForward(next, signalName);
                dest=[];
                for i=1:length(intermediate)
                    dest=traverseBusForward(intermediate(i), signal);
                end
            else
                intermediate=traverseBusForward(next, signalName);
                dest=[];
                for i=1:length(intermediate)
                    dest=traverseBusForward(intermediate(i), signal);
                end
            end
        case 'BusSelector'
            %base case for recursion
            outputs=get_param(next, 'OutputSignals');
            outputs=regexp(outputs, ',', 'split');
            portNum=find(strcmp(outputs(:), signal));
            dest=get_param(next, 'PortConnectivity');
            dest=dest(1+portNum).DstBlock;
        case 'Goto'
            froms=findFromsInScope(next);
            dest=[];
            for i=1:length(froms)
                dest(end+1)=traverseBusForward(froms(i), signal);
            end
        case 'SubSystem'
            blockList(end+1)=next;
            blockLines=get_param(block, 'LineHandles');
            nextLines=get_param(next, 'LineHandles');
            line=intersect(blockLines, nextLines);
            dstPorts=get_param(line, 'DstPortHandle');
            for j=1:length(dstPorts)
                portNum=get_param(dstPorts(y), 'PortNumber');
                inport=find_system(next, 'BlockType', 'Inport', 'Port', portNum);
                traverseBusForward(inport, signal);
            end
        case 'Outport'
            portNum=get_param(next, 'Port');
            parent=get_param(next, 'parent');
            port=find_system(get_param(parent, 'parent'), 'SearchDepth', 1, 'FindAll', 'on', ...
                'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', portNum);
            connectedBlock=get_param(port, 'DstBlock');
            dest=traverseBusForward(connectedBlock, signal);
        otherwise
            dest=traverseBusForward(next, signal);
    end
end
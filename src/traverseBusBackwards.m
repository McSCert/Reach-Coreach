function [dest, path, blockList, exit]=traverseBusBackwards(block, signal, path, blockList)
    %go until you hit a bus creator, then return the path taken there as
    %well as the exiting port
    blockList(end+1)=get_param(block, 'Handle');
    portConnectivity=get_param(block, 'PortConnectivity');
    srcBlocks=portConnectivity(end).SrcBlock;
    next=srcBlocks(1);
    portHandles=get_param(block, 'PortHandles');
    path(end+1)=portHandles.Inport;
    blockType=get_param(next, 'BlockType');
    switch blockType
        case 'BusSelector'
            blockLines=get_param(block, 'LineHandles');
            blockLines=blockLines.Outport;
            nextLines=get_param(next, 'LineHandles');
            nextLines=nextLines.Inport;
            line=intersect(blockLines, nextLines);
            signalName=get_param(line, 'Name');
            if ~isempty(signalName)
                dstPort=get_param(line, 'DstPortHandle');
                portNum=get_param(dstPort, 'PortNumber');
                signalName=['signal' num2str(portNum)];
                intermediate=traverseBusForward(next, signalName);
                dest=[];
                exit=[];
                for i=1:length(intermediate)
                    [tempDest, tempPath, tempBlockList, tempExit]=traverseBusForward(intermediate(i), signal, path, blockList);
                    dest=[dest tempDest];
                    exit=[exit tempExit];
                    blockList=[blockList tempBlockList];
                    path=[path, tempPath];
                end
            else
                intermediate=traverseBusForward(next, signalName);
                dest=[];
                exit=[];
                for i=1:length(intermediate)
                    [tempDest, tempPath, tempBlockList, tempExit]=traverseBusForward(intermediate(i), signal, path, blockList);
                    dest=[dest tempDest];
                    exit=[exit tempExit];
                    blockList=[blockList tempBlockList];
                    path=[path, tempPath];
                end
            end
        case 'BusCreator'
            %base case for recursion
            blockList(end+1)=next;
            outputs=get_param(next, 'OutputSignals');
            outputs=regexp(outputs, ',', 'split');
            portNum=find(strcmp(outputs(:), signal));
            dest=get_param(next, 'PortConnectivity');
            dest=dest(1+portNum).DstBlock;
            exit=get_param(next, 'PortHandles');
            exit=exit.Outport;
            exit=exit(portNum);
        case 'From'
            blockList(end+1)=next;
            gotos=findGotosInScope(next);
            dest=[];
            exit=[];
            for i=1:length(gotos)
                [tempDest, tempPath, tempBlockList, tempExit]=traverseBusBackwards(gotos(i), signal, path, blockList);
                dest=[dest tempDest];
                exit=[exit tempExit];
                blockList=[blockList tempBlockList];
                path=[path, tempPath];
            end
        case 'SubSystem'
            blockList(end+1)=next;
            blockLines=get_param(block, 'LineHandles');
            nextLines=get_param(next, 'LineHandles');
            line=intersect(blockLines, nextLines);
            srcPorts=get_param(line, 'SrcPortHandle');
            for j=1:length(srcPorts)
                portNum=get_param(srcPorts(j), 'PortNumber');
                inport=find_system(next, 'BlockType', 'Outport', 'Port', portNum);
                [dest, path, blockList, exit]=traverseBusBackwards(inport, signal, path, blockList);
            end
        case 'Inport'
            portNum=get_param(next, 'Port');
            parent=get_param(next, 'parent');
            blockList(end+1)=parent;
            port=find_system(get_param(parent, 'parent'), 'SearchDepth', 1, 'FindAll', 'on', ...
                'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', portNum);
            path(end+1)=port;
            connectedBlock=get_param(port, 'SrcBlock');
            [dest, path, blockList, exit]=traverseBusBackwards(connectedBlock, signal, path, blockList);
        otherwise
            [dest, path, blockList, exit]=traverseBusBackwards(next, signal, path, blockList);
    end
end
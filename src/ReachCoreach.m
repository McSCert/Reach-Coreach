classdef ReachCoreach < handle
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    properties
        RootSystemName
        ReachedObjects
        CoreachedObjects
        PortsToTraverse
        PortsToTraverseCo
        TraversedPorts
        TraversedPortsCo
        Color
        BGColor
    end
    
    methods
        
        function object = ReachCoreachRef(RootSystemName)
            %initializing attributes
            object.RootSystemName=RootSystemName;
            object.ReachedObjects=[];
            object.CoreachedObjects=[];
        end
        
        function setColor(object, color1, color2)
            %set the desired colors to hilite blocks
            object.Color=color1;
            object.BGColor=color2;
        end
        
        function hiliteObjects(object)
            %color hilite all of the reached/coreached blocks
            hilite_system(object.ReachedObjects);
            
            for i=1:length(object.CoreachedObjects)
                hilite_system(object.CoreachedObjects(i));
            end
        end
        
        function slice(object)
            %remove all blocks other than the reached/coreached blocks
            
        end
        
        function clear(object)
            %clear reached/coreached blocks from selection
            object.ReachedObjects=[];
            object.CoreachedObjects=[];
        end
        
        function reachAll(object, selection)
            %get all the outports from the selected blocks
            for i=1:length(selection)
                object.ReachedObjects(end+1)=get_param(selection{i}, 'handle');
                ports=get_param(selection{i}, 'PortHandles');
                object.PortsToTraverse=[object.PortsToTraverse ports.Outport];
            end
            %reach from each in the list of ports to traverse
            while ~isempty(object.PortsToTraverse)
                port=object.PortsToTraverse(end);
                object.PortsToTraverse(end)=[];
                reach(object, port)
            end
            object.hiliteObjects();
        end
        
        function reach(object, port)
            %check if this port was already traversed
            if isempty(setdiff(port, object.TraversedPorts))
                return
            end
            
            %get block port belongs to
            block=get_param(port, 'parent');
            
            %mark this port as traversed
            object.TraversedPorts(end+1)=port;
            
            %get line from the port, and then get the destination blocks
            line=get_param(port, 'line');
            object.ReachedObjects(end+1)=line;
            nextBlocks=get_param(line, 'DstBlockHandle');
            
            for i=1:length(nextBlocks)
                %add block to list of reached objects
                object.ReachedObjects(end+1)=nextBlocks(i);
                %get blocktype for switch case
                blockType=get_param(nextBlocks(i), 'BlockType');
                %switch statement that handles the reaching of blocks
                %differently.
                switch blockType
                    case 'Goto'
                        froms=findFromsInScope(nextBlocks(i));
                        for j=1:length(froms)
                            object.ReachedObjects(end+1)=get_param(froms{j}, 'handle');
                            outport=get_param(froms{j}, 'PortHandles');
                            outport=outport.Outport;
                            object.PortsToTraverse(end+1)=outport;
                        end
                        
                    case 'DataStoreWrite'
                        reads=findDataStoreReads(nextBlocks{i});
                        for j=1:length(reads)
                            object.ReachedObjects(end+1)=reads(j);
                            outport=get_param(reads(j), 'PortHandles');
                            outport=outport.Outport;
                            object.PortsToTraverse(end+1)=outport;
                        end
                    case 'SubSystem'
                        dstPorts=get_param(line, 'DstPortHandle');
                        for j=1:length(dstPorts)
                            portNum=get_param(dstPorts(j), 'PortNumber');
                            inport=find_system(nextBlocks(i), 'BlockType', 'Inport', 'Port', num2str(portNum));
                            object.ReachedObjects(end+1)=get_param(inport, 'Handle');
                            outport=get_param(inport, 'PortHandles');
                            outport=outport.Outport;
                            object.PortsToTraverse(end+1)=outport;
                        end
                    case 'Outport'
                        portNum=get_param(nextBlocks(i), 'Port');
                        parent=get_param(nextBlocks(i), 'parent');
                        if ~isempty(get_param(parent, 'parent'))
                            port=find_system(get_param(parent, 'parent'), 'SearchDepth', 1, 'FindAll', 'on', ...
                                'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', str2num(portNum));
                            object.ReachedObjects(end+1)=get_param(parent, 'handle');
                            object.PortsToTraverse(end+1)=port;
                        end
                        
                    case 'WhileIterator'
                        %get errything
                        blocks=find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                        ports=find_system(object.RootSystemName, 'LookUnderMasks', 'all', 'FollowLinks', 'on');
                    case 'BusSelector'
                        blockLines=get_param(block, 'LineHandles');
                        blockLines=blockLines.Outport;
                        nextLines=get_param(nextBlocks(i), 'LineHandles');
                        nextLines=nextLines.Inport;
                        line=intersect(blockLines, nextLines);
                        signalName=get_param(line, 'Name');
                        if ~isempty(signalName)
                            dstPort=get_param(line, 'DstPortHandle');
                            portNum=get_param(dstPort, 'PortNumber');
                            dest=traverseBusForwards(nextBlocks(i), ['signal' num2str(portNumber)]);
                        else
                            dest=traverseBusForwards(nextBlocks(i), signalName);
                        end
                    case 'BusCreator'
                        blockLines=get_param(block, 'LineHandles');
                        blockLines=blockLines.Outport;
                        nextLines=get_param(nextBlocks(i), 'LineHandles');
                        nextLines=nextLines.Inport;
                        line=intersect(blockLines, nextLines);
                        signalName=get_param(line, 'Name');
                        if isempty(signalName)
                            dstPort=get_param(line, 'DstPortHandle');
                            portNum=get_param(dstPort, 'PortNumber');
                            signalName=['signal' num2str(portNum)];
                        end
                        [~,path,blockList,exit]=traverseBusForwards(nextBlocks(i), signalName, [], []);
                        object.TraversedPorts=[object.TraversedPorts path];
                        object.ReachedObjects=[object.ReachedObjects blockList];
                        object.portsToTraverse=[object.portsToTraverse exit];
                    case 'If'
                        ports=get_param(nextBlocks(i), 'PortHandles');
                        outports=ports.Outport;
                        blockLines=get_param(block, 'LineHandles');
                        blockLines=blockLines.Outport;
                        nextLines=get_param(nextBlocks(i), 'LineHandles');
                        nextLines=nextLines.Inport;
                        line=intersect(blockLines, nextLines);
                        dstPort=get_param(line, 'DstPortHandle');
                        portNum=get_param(dstPort, 'PortNumber');
                        cond=['u' num2str(portNum)];
                        expressions=get_param(nextBlocks(i), 'ElseIfExpressions');
                        if ~isempty(expressions)
                            expressions=regexp(expressions, ',', 'split');
                            expressions=[{get_param(nextBlocks(i), 'IfExpression')} expressions];
                        else
                            expressions={};
                            expressions{end+1}=get_param(nextBlocks(i), 'IfExpression');
                        end
                        for j=1:length(expressions)
                            if regexp(expressions{j}, cond)
                                object.PortsToTraverse=outports(j);
                            end
                        end
                    otherwise
                        ports=get_param(nextBlocks(i), 'PortHandles');
                        outports=ports.Outport;
                        for j=1:length(outports)
                            object.PortsToTraverse=outports(j);
                        end                     
                end
            end
        end
        
        function source=traverseBusBackwards(block, signal)
            portConnectivity=get_param(block, 'PortConnectivity');
            srcBlocks=portConnectivity.SrcBlock;
            next=srcBlocks(1);
            blockType=get_param(next, 'BlockType');
            switch blockType
                case 'BusSelector'
                    
                case 'BusCreator'
                    
                case 'From'
                    
                case 'SubSystem'
                    
                case 'Inport'
                    
                otherwise
                    
            end
        end
    end


end


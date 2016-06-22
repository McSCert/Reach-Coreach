classdef ReachCoreachRef < handle
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
        ObjectsToReach
        ObjectsToCoreach
        Color
        BGColor
    end
    
    methods
        
        function object = ReachCoreachRef(RootSystemName)
            %initializing attributes
            object.RootSystemName=RootSystemName;
            object.ReachedObjects=[];
            object.CoreachedObjects=[];
            object.ObjectsToReach=[];
            object.ObjectsToCoreach=[];
        end
        
        function setColor(object, color1, color2)
            %set the desired colors to hilite blocks
            object.Color=color1;
            object.BGColor=color2;
        end
        
        function hiliteObjects(object)
            %color hilite all of the reached/coreached blocks
            for i=1:length(object.ReachedObjects)
                hilite_system(object.ReachedObjects(i));
            end
            
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
            object.ObjectsToReach=[];
            object.ObjectsToCoreach=[];
        end
        
        function reachAll(object, selection)
            %get all the outports from the selected blocks
            for i=1:length(selection)
                ports=get_param(selection{i}, 'PortHandles');
                object.PortsToTraverse=[object.PortsToTraverse ports.Outport];
            end
            %reach from each in the list of ports to traverse
            while ~isempty(object.PortsToTraverse)
                port=object.PortsToTraverse(end);
                object.PortsToTraverse(end)=[];
                reach(object, port)
            end
        end
        
        function reach(object, port)
            %check if this port was already traversed
            if isempty(setdiff(port, object.TraversedPorts))
                return
            end
            
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
                        froms=findFromsInScope(nextBlocks{i});
                        for j=1:length(froms)
                            object.ReachedObjects(end+1)=froms(j);
                            outport=get_param(froms(j), 'PortHandles');
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
                            portNum=get_param(dstPorts(y), 'PortNumber');
                            inport=find_system(nextBlocks(i), 'BlockType', 'Inport', 'Port', portNum);
                            object.ReachedObjects(end+1)=get_param(inport, 'Handle');
                            outport=get_param(inport, 'PortHandles');
                            outport=outport.Outport;
                            object.PortsToTraverse(end+1)=outport;
                        end
                    case 'Outport'
                        portNum=get_param(nextBlocks(i), 'Port');
                        parent=get_param(nextBlocks(i), 'parent');
                        port=find_system(get_param(parent, 'parent'), 'SearchDepth', 1, 'FindAll', 'on', ...
                            'type', 'port', 'parent', parent, 'PortType', 'outport', 'PortNumber', portNum);
                        object.ReachedObjects=parent;
                        object.PortsToTraverse(end+1)=port;
                        
                    case 'WhileIterator'
                        
                    case 'ForIterator'
                        
                    case 'BusSelector'
                        
                    case 'If'
                        
                    otherwise
                        ports=get_param(nextBlocks{i}, 'PortHandles');
                        outports=ports.Outport;
                        for j=1:length(outports)
                            object.PortsToTraverse=outports(j);
                        end                     
                end
            end
        end
        
        
        function reads=findReadsInScope(block)
            
        end
        
        function writes=findWritesInScope(block)
            
        end
        
        function dest=traverseBusForward(block, signal)
            %go until you hit a bus creator, then return (?)
            portConnectivity=get_param(block, 'PortConnectivity');
            dstBlocks=portConnectivity.DstBlock;
            next=dstBlocks(1);
            blockType=get_param(next, 'BlockType');
            switch blockType
                case 'BusCreator'
                    
                case 'BusSelector'
                    
                case 'Goto'
                    
                case 'SubSystem'
                    
                case 'Outport'
                    
                otherwise
                    
            end
        end
        
        function source=findCreatorForSelector(block, signal)
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


end


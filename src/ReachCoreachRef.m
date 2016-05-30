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
                        
                    case 'DataStoreWrite'
                        
                    case 'SubSystem'
                        
                    case 'Outport'
                        
                    case 'WhileIterator'
                        
                    case 'ForIterator'
                        
                    case 'BusSelector'
                        
                    case 'If'
                        
                    otherwise
                        
                end
            end
        end
        
        function froms=findFromsInScope(block)
            %function for finding all of the from blocks for a
            %corresponding goto
            tag=get_param(block, 'GotoTag');
            scopedTags=find_system(bdroot(block), 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
            level=get_param(block, 'parent');
            if isempty(scopedTags)
                froms=find_system(level, 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', tag);
                return
            end
            correctScope='asdf';
            for i=1:length(scopedTags)
                tagParent=get_param(scopedTags(i), 'parent');
                
                aboveCheck=strfind(level, tagParent);
                if (aboveCheck(1)==1)
                    
                end
            end
        end
        
        function reads=findReadsInScope(block)
            
        end
    end


end


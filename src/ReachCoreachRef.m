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
                        
                end
            end
        end
        
        function froms=findFromsInScope(block)
            %function for finding all of the from blocks for a
            %corresponding goto
            tag=get_param(block, 'GotoTag');
            scopedTags=find_system(bdroot(block), 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
            level=get_param(block, 'parent');
            %if there are no corresponding tags, goto is assumed to be
            %local, and all local froms corresponding to the tag are found
            if isempty(scopedTags)
                froms=find_system(level, 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', tag);
                return
            end
            
            %currentLevel is the current assumed level of the scope of the
            %goto
            currentLevel=level;
            currentLimit='';
            
            %declaration of the level of the goto being split into
            %subsystem name tokens
            levelSplit=regexp(currentLevel, 'split', '/');
            
            for i=1:length(scopedTags)
                %get level of subsystem for visibility tag
                tagScope=get_param(scopedTags(i), 'parent');
                tagScopeSplit=regexp(tagScope, '/', 'split');
                inter=intersect(tagScopeSplit, levelSplit);
                %check if the visibility tag is above the goto in subsystem
                %hierarchy
                if (length(inter)==length(tagScopeSplit))
                    currentLevelSplit=regexp(currentLevel, '/', 'split');
                    %if it's the closest to the goto, note that as the correct
                    %scope for the visibility block
                    if length(currentLevelSplit)<length(tagScopeSplit)
                        currentLevel=tagScope;
                    end
                %if a visibility tag is below the level of the goto in
                %subsystem hierarchy
                elseif (length(inter)==length(levelSplit))
                    currentLimitSplit=regexp(currentLevel, '/', 'split');
                    if length(currentLimitSplit)<length(tagScopeSplit)
                        currentLimit=tagScope;
                    end
                end
            end
            %get all froms within the scope of the tag selected goto
            %belongs to
            froms=find_system(currentLevel, 'BlockType', 'From', 'GotoTag', tag);
            fromsToExclude=find_system(currentLimit, 'BlockType', 'From', 'GotoTag', tag);
            froms=setdiff(froms, fromsToExclude);
        end
        
        function goto=findGotoInScope(block)
            tag=get_param(block, 'GotoTag');
            goto=find_system(get_param(block, 'parent'), 'BlockType', 'Goto', 'GotoTag', tag, 'TagVisibility', 'local');
            if ~isempty(goto)
                return
            end
            scopedTags=find_system(bdroot(block), 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
            level=get_param(block, 'parent');
            levelSplit=regexp(level, '/', 'split');
            
            currentLevel=level;
            currentLimit='';
            
            for i=1:length(scopedTags)
                tagScope=get_param(scopedTags{i}, 'parent');
                tagScopeSplit=regexp(tagScope, '/', 'split');
                inter=intersect(tagScopeSplit, levelSplit);
                
                if (length(inter)==length(tagScopeSplit))
                    currentLevelSplit=regexp(currentLevel, '/', 'split');
                    %if it's the closest to the goto, note that as the correct
                    %scope for the visibility block
                    if length(currentLevelSplit)<length(tagScopeSplit)
                        currentLevel=tagScope;
                    end
                    %if a visibility tag is below the level of the goto in
                    %subsystem hierarchy
                elseif (length(inter)==length(levelSplit))
                    currentLimitSplit=regexp(currentLevel, '/', 'split');
                    if length(currentLimitSplit)<length(tagScopeSplit)
                        currentLimit=tagScope;
                    end
                end
            end
            
            % Get the corresponding gotos for a given from that's in the
            % correct scope.
            goto=find_system(currentLevel, 'BlockType', 'Goto', 'GotoTag', tag);
            gotosToExclude=find_system(currentLimit, 'BlockType', 'Goto', 'GotoTag', tag);
            goto=setdiff(goto, gotosToExclude);
            
            
        end
        
        function reads=findReadsInScope(block)
            
        end
        
        function writes=findWritesInScope(block)
            
        end
        
        function selector=findSelectorForBus(busCreator)
            
        end
        
        function creator=findCreatorForSelector(busSelector)
            
        end
    end


end


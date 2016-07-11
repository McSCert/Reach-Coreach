function writes = findWritesInScope(block)
%function for finding all the corresponding data store reads of a data
%store write block
    dataStoreName=get_param(block, 'DataStoreName');
    dataStoreMems=find_system(bdroot(block), 'BlockType', 'DataStoreMemory', 'DataStoreName', dataStoreName);
    level=get_param(block, 'parent');
    currentLevel=level;
    
    %level of the data store write block being split into subsystem name
    %tokens
    levelSplit=regexp(currentLevel, '/', 'split');
    
    for i=1:length(dataStoreMems)
        %get level of subsystem for data store mem
        memScope=get_param(dataStoreMems{i}, 'parent');
        memScopeSplit=regexp(memScope, '/', 'split');
        inter=intersect(memScopeSplit, levelSplit);
        %check if the data store memory is above the write in system
        %hierarchy
        if (length(inter)==length(memScopeSplit))
            currentLevelSplit=regexp(currentLevel, '/', 'split');
            %if it's the closest to the write, note that as the correct
            %scope for the data store memory block
            if length(currentLevelSplit)>length(memScopeSplit)
                currentLevel=memScope;
            end
        end
    end
    
    memBlock=find_system(currentLevel, 'SearchDepth', 1, 'BlockType', 'DataStoreMemory', 'DataStoreName', dataStoreName);
    writes=findReadWritesInScope(memBlock{1});
    blocksToExclude=find_system(currentLevel, 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName);
    writes=setdiff(writes, blocksToExclude);

end
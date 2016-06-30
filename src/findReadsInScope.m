function reads = findReadsInScope(block)
%function for finding all the corresponding data store reads of a data
%store write block
    dataStoreName=get_param(block, 'DataStoreName');
    dataStoreMems=find_system(bdroot(block), 'BlockType', 'DataStoreMemory', 'DataStoreName', dataStoreName);
    level=get_param(block, 'parent');
    currentLevel=level;
    currentLimit='';
    
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
            if length(currentLevelSplit)<length(memScopeSplit)
                currentLevel=memScope;
            end
        elseif (length(inter)==length(levelSplit))
            currentLimitSplit=regexp(currentLevel, '/', 'split');
            if length(currentLimitSplit)<length(memScopeSplit)
                currentLimit=memScope;
            end
        end
    end
    
    reads=find_system(currentLevel, 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName);
    if ~isempty(currentLimit)
        readsToExclude=find_system(currentLimit, 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName);
        reads=setdiff(reads, readsToExclude);
    end

end


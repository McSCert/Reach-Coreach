function mem = findDataStoreMemory(block)
%FINDDATASTOREMEMORY finds the associated data store memory block to a data
%store read or write

    %make sure input is a valid data store read/write block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType=get_param(block, 'BlockType');
        assert(strcmp(blockType, 'DataStoreRead')||strcmp(blockType, 'DataStoreWrite'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            'Block parameter is not a read or write block.' char(10)])
        help(mfilename)
        return
    end

    dataStoreName=get_param(block, 'DataStoreName');
    dataStoreMems=find_system(bdroot(block), 'FollowLinks', 'on', 'BlockType', 'DataStoreMemory', 'DataStoreName', dataStoreName);
    level=get_param(block, 'parent');
    currentLevel='';
    
    %level of the data store write block being split into subsystem name
    %tokens
    levelSplit=regexp(level, '/', 'split');
    
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
            if isempty(currentLevel)||length(currentLevelSplit)<length(memScopeSplit)
                currentLevel=memScope;
            end
        end
    end
    
    if ~isempty(currentLevel)
        mem=find_system(currentLevel,'FollowLinks', 'on', 'SearchDepth', 1, 'BlockType', 'DataStoreMemory', 'DataStoreName', dataStoreName);
        mem=mem{1};
    else
        mem={};
    end

end


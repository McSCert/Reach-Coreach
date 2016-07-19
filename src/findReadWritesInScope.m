function blockList = findReadWritesInScope(block)
%FINDREADWRITESINSCOPE This functino finds all the associated data store
%read and data store write blocks of a data store memory block

    %make sure input is a valid data store read/write block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'DataStoreMemory'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            'Block parameter is not a data store memory block.' char(10)])
        help(mfilename)
        blockList={};
        return
    end

    %get all other data store memory blocks
    dataStoreName = get_param(block, 'DataStoreName');
    blockParent = get_param(block, 'parent');
    memsSameName = find_system(blockParent, 'FollowLinks', 'on', 'BlockType', 'DataStoreMemory', 'DataStoreName', dataStoreName);
    memsSameName = setdiff(memsSameName, block);
    
    %any read/write blocks in the scope of other data store memory blocks
    %are listed as not to be included in the list of associated
    %reads/writes of input data store memory block
    blocksToExclude ={};
    for i = 1:length(memsSameName)
        memParent = get_param(memsSameName{i}, 'parent');
        blocksToExclude = [blocksToExclude; find_system(memParent, 'FollowLinks', 'on', 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName)];
        blocksToExclude = [blocksToExclude; find_system(memParent, 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite', 'DataStoreName', dataStoreName)];
    end
    
    %removes the blocks to exclude from the list of reads/writes with the
    %same name as input data store memory block
    blockList = find_system(blockParent, 'FollowLinks', 'on', 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName);
    blockList = [blockList; find_system(blockParent, 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite', 'DataStoreName', dataStoreName)];
    blockList = setdiff(blockList, blocksToExclude);

end


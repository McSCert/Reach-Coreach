function reads = findReadsInScope(block)
%function for finding all the corresponding data store reads of a data
%store write block

    %make sure input is a valid data store write block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'DataStoreWrite'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            'Block parameter is not a write block.' char(10)])
        help(mfilename)
        return
    end
    
    dataStoreName = get_param(block, 'DataStoreName');
    memBlock = findDataStoreMemory(block);
    reads = findReadWritesInScope(memBlock);
    blocksToExclude = find_system(get_param(memBlock, 'parent'), 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite', 'DataStoreName', dataStoreName);
    reads = setdiff(reads, blocksToExclude);

end


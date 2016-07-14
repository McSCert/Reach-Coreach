function reads = findReadsInScope(block)
%function for finding all the corresponding data store reads of a data
%store write block
    dataStoreName=get_param(block, 'DataStoreName');
    memBlock=findDataStoreMemory(block);
    reads=findReadWritesInScope(memBlock);
    blocksToExclude=find_system(get_param(memBlock, 'parent'), 'FollowLinks', 'on', 'BlockType', 'DataStoreWrite', 'DataStoreName', dataStoreName);
    reads=setdiff(reads, blocksToExclude);

end


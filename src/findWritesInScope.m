function writes = findWritesInScope(block)
%FINDWRITESINSCOPE function for finding all associated writes of a data
%store read block
    dataStoreName=get_param(block, 'DataStoreName');
    memBlock=findDataStoreMemory(block);
    writes=findReadWritesInScope(memBlock);
    blocksToExclude=find_system(get_param(memBlock, 'parent'), 'FollowLinks', 'on', 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName);
    writes=setdiff(writes, blocksToExclude);

end
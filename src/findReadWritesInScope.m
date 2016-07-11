function blockList = findReadWritesInScope(block)
%FINDREADWRITESINSCOPE This functino finds all the associated data store
%read and data store write blocks of a data store memory block

    dataStoreName=get_param(block, 'DataStoreName');
    blockParent=get_param(block, 'parent');
    memsSameName=find_system(blockParent, 'BlockType', 'DataStoreMemory', 'DataStoreName', dataStoreName);
    memsSameName=setdiff(memsSameName, block);
    
    blocksToExclude={};
    for i=1:length(memsSameName)
        memParent=get_param(memsSameName{i}, 'parent');
        blocksToExclude=[blocksToExclude; find_system(memParent, 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName)];
        blocksToExclude=[blocksToExclude; find_system(memParent, 'BlockType', 'DataStoreWrite', 'DataStoreName', dataStoreName)];
    end
    
    blockList=find_system(blockParent, 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName);
    blockList=[blockList; find_system(blockParent, 'BlockType', 'DataStoreWrite', 'DataStoreName', dataStoreName)];
    blockList=setdiff(blockList, blocksToExclude);

end


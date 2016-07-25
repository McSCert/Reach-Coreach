function writes = findWritesInScope(block)
% FINDWRITESINSCOPE Find all the Data Store Writes associated with a Data
% Store Read block.

    % Ensure input is a valid Data Store Read block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'DataStoreRead'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            'Block parameter is not a read block.' char(10)])
        help(mfilename)
        writes = {};
        return
    end

    dataStoreName = get_param(block, 'DataStoreName');
    memBlock = findDataStoreMemory(block);
    writes = findReadWritesInScope(memBlock);
    blocksToExclude = find_system(get_param(memBlock, 'parent'), 'FollowLinks', 'on', 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName);
    writes = setdiff(writes, blocksToExclude);
end

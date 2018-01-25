function writes = findWritesInScopeRCR(obj, block, flag)
% FINDWRITESINSCOPE Find all the Data Store Writes associated with a Data
% Store Read block.

    if isempty(block)
        writes = {};
        return
    end

    % Ensure input is a valid Data Store Read block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'DataStoreRead'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            ' Block parameter is not a Data Store Read block.' char(10)])
        help(mfilename)
        writes = {};
        return
    end

    dataStoreName = get_param(block, 'DataStoreName');
    
    if flag
        try
            writes = obj.dswMap(dataStoreName);
        catch
            writes = {};
        end
        return
    end
    
    memBlock = findDataStoreMemoryRCR(obj, block, flag);
    writes = findReadWritesInScopeRCR(obj, memBlock, flag);
    blocksToExclude = obj.dsrMap(dataStoreName);
    writes = setdiff(writes, blocksToExclude);
end
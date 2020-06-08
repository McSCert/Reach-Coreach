function writes = findWritesInScopeRCR(obj, block, flag)
    % FINDWRITESINSCOPE Find all the Data Store Writes associated with a Data
    % Store Read block.
    %
    % 	Inputs:
    %       obj     The reachcoreach object containing data store mappings.
    %       block   The read block of interest as a char array, an empty cell
    %               array, or a 1x1 cell array containing the block as a char
    %               array.
    %       flag    The flag indicating whether shadowing data stores are in the
    %               model.
    %
    % 	Outputs:
    %		froms   The data store write corresponding to input "block".
    %
    
    % Input Handling:
    if iscell(block) && ~isempty(block)
        assert(length(block) == 1, 'Something went wrong, block input too long.')
        block = block{1};
    end
    
    %
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
    
    %
    if ~isempty(obj.implicitMaps)
        if obj.implicitMaps.r2w.isKey(block)
            writes = obj.implicitMaps.r2w(block);
            return
        end
    end
    
    %
    dataStoreName = get_param(block, 'DataStoreName');
    
    if ~flag
        if obj.dswMap.isKey(dataStoreName)
            writes = obj.dswMap(dataStoreName);
        else
            writes = {};
        end
        return
    end
    
    memBlock = findDataStoreMemoryRCR(obj, block, flag);
    if length(memBlock) == 1
        writes = findReadWritesInScopeRCR(obj, memBlock{1}, flag);
    else
        writes = {};
    end
    if obj.dsrMap.isKey(dataStoreName)
        blocksToExclude = obj.dsrMap(dataStoreName);
    else
        blocksToExclude = {};
    end
    writes = setdiff(writes, blocksToExclude);
end
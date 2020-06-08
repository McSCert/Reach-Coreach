function reads = findReadsInScopeRCR(obj, block, flag)
    % FINDREADSINSCOPE Find all the Data Store Read blocks associated with a Data
    % Store Write block.
    %
    % 	Inputs:
    % 		obj     The reachcoreach object containing data store mappings.
    %       block   The write block of interest as a char array, an empty cell
    %               array, or a 1x1 cell array containing the block as a char
    %               array.
    %       flag    The flag indicating whether shadowing data stores are in the
    %               model.
    %
    % 	Outputs:
    %		froms   The data store read corresponding to input "block".
    %
    
    % Input Handling:
    if iscell(block) && ~isempty(block)
        assert(length(block) == 1, 'Something went wrong, block input too long.')
        block = block{1};
    end
    
    %
    if isempty(block)
        reads = {};
        return
    end
    
    % Ensure block input is a valid Data Store Write block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'DataStoreWrite'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            ' Block parameter is not a Data Store Write block.' char(10)])
        help(mfilename)
        reads = {};
        return
    end
    
    %
    if ~isempty(obj.implicitMaps)
        if obj.implicitMaps.w2r.isKey(block)
            reads = obj.implicitMaps.w2r(block);
            return
        end
    end
    
    %
    dataStoreName = get_param(block, 'DataStoreName');
    
    if ~flag
        if obj.dsrMap.isKey(dataStoreName)
            reads = obj.dsrMap(dataStoreName);
        else
            reads = {};
        end
        return
    end
    
    memBlock = findDataStoreMemoryRCR(obj, block, flag);
    if length(memBlock) == 1
        reads = findReadWritesInScopeRCR(obj, memBlock{1}, flag);
    else
        reads = {};
    end
    if obj.dswMap.isKey(dataStoreName)
        blocksToExclude = obj.dswMap(dataStoreName);
    else
        blocksToExclude = {};
    end
    reads = setdiff(reads, blocksToExclude);
end
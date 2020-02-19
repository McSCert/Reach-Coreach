function reads = findReadsInScopeRCR(obj, block, flag)
% FINDREADSINSCOPE Find all the Data Store Read blocks associated with a Data
% Store Write block.
%
% 	Inputs:
% 		obj    The reachcoreach object containing data store mappings
%       block  The write block of interest
%       flag   The flag indicating whether shadowing data stores are in the
%              model
%
% 	Outputs:
%		froms    Thedata store read corresponding to input "block"

    if isempty(block)
        reads = {};
        return
    end

    % Ensure input is a valid data store write block
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
    
    dataStoreName = get_param(block, 'DataStoreName');
    
    % TODO: The logic seems to make more sense for this condition to be ~flag,
    % but in testing this performs better (either way, these functions should
    % probably be updated)
    if flag
        try
            reads = obj.dsrMap(dataStoreName);
        catch
            reads = {};
        end
        return
    end
    
    memBlock = findDataStoreMemoryRCR(obj, block, flag);
    reads = findReadWritesInScopeRCR(obj, memBlock, flag);
    blocksToExclude = obj.dswMap(dataStoreName);
    reads = setdiff(reads, blocksToExclude);
end
function blockList = findReadWritesInScopeRCR(obj, block, flag)
% FINDREADWRITESINSCOPE Find all the Data Store Read and Data Store Write 
% blocks associated with a Data Store Memory block.
%
% 	Inputs:
% 		obj        The reachcoreach object containing data store mappings
%       block      The data store memory block of interest
%       flag       The flag indicating whether shadowing data stores are in the
%                  model
%
% 	Outputs:
%		blockList  The cell array of reads and writes corresponding to the
%		           input "block"

    if isempty(block)
        blockList = {};
        return
    end

    % Ensure input is a valid Data Store Memory block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'DataStoreMemory'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            ' Block parameter is not a Data Store Memory block.' char(10)])
        help(mfilename)
        blockList = {};
        return
    end

    % Get all other Data Store Memory blocks
    dataStoreName = get_param(block, 'DataStoreName');
    
    if ~flag
        if obj.dsrMap.isKey(dataStoreName)
            dataStoreReads = obj.dsrMap(dataStoreName);
        else
            dataStoreReads = {};
        end
        
        if obj.dswMap.isKey(dataStoreName)
            dataStoreWrites = obj.dswMap(dataStoreName);
        else
            dataStoreWrites = {};
        end
        blockList = [dataStoreReads; dataStoreWrites];
        return
    end
    
    blockParent = get_param(block, 'parent');
    if obj.dsmMap.isKey(dataStoreName)
        memsSameName = obj.dsmMap(dataStoreName);
    else
        memsSameName = {};
    end
    memsSameName = setdiff(memsSameName, block);
    
    % Exclude any Data Store Read/Write blocks which are in the scope of 
    % other Data Store Memory blocks
    blocksToExclude = {};
    for i = 1:length(memsSameName)
        dsmFlag = 0;
        dsmParent = get_param(memsSameName{i}, 'parent');
        if length(dsmParent) > length(blockParent)
            if strcmp(blockParent, dsmParent(1:length(blockParent)))
                dsmFlag = 1;
            end
        end
        if dsmFlag
            memParent = get_param(memsSameName{i}, 'parent');
            blocksToExclude = [blocksToExclude; find_system(memParent, 'FollowLinks', ...
                'on', 'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName)];
            blocksToExclude = [blocksToExclude; find_system(memParent, 'FollowLinks', ...
                'on', 'BlockType', 'DataStoreWrite', 'DataStoreName', dataStoreName)];
        end
    end
    
    % Remove the blocks to exclude from the list of Reads/Writes with the
    % same name as input Data Store Memory block
    blockList = find_system(blockParent, 'FollowLinks', 'on', ...
        'BlockType', 'DataStoreRead', 'DataStoreName', dataStoreName);
    blockList = [blockList; find_system(blockParent, 'FollowLinks', 'on', ...
        'BlockType', 'DataStoreWrite', 'DataStoreName', dataStoreName)];
    blockList = setdiff(blockList, blocksToExclude);
end
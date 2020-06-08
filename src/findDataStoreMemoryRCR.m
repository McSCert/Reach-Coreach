function mem = findDataStoreMemoryRCR(obj, block, flag)
    % FINDDATASTOREMEMORY Find the Data Store Memory block of a Data Store
    % Read or Write block.
    %
    % 	Inputs:
    % 		obj     The reachcoreach object containing data store mappings.
    %       block   The data store read or write block of interest as a char
    %               array, an empty cell array, or a 1x1 cell array containing
    %               the block as a char array.
    %       flag    The flag indicating whether shadowing data stores are in the
    %               model.
    %
    % 	Outputs:
    %		mem     The data store memory block corresponding to input "block".
    %
    
    % Input Handling:
    if iscell(block) && ~isempty(block)
        assert(length(block) == 1, 'Something went wrong, block input too long.')
        block = block{1};
    end
    
    %
    if isempty(block)
        mem = {};
        return
    end
    
    % Ensure input block is a valid Data Store Read/Write block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'DataStoreRead') || strcmp(blockType, 'DataStoreWrite'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            ' Block parameter is not a Data Store Read or Write block.' char(10)])
        help(mfilename)
        mem = {};
        return
    end
    
    %
    if ~isempty(obj.implicitMaps)
        if obj.implicitMaps.rw2m.isKey(block)
            mem = obj.implicitMaps.rw2m(block);
            return
        end
    end
    
    %
    dataStoreName = get_param(block, 'DataStoreName');
    if obj.dsmMap.isKey(dataStoreName)
        dataStoreMems = obj.dsmMap(dataStoreName);
    else
        dataStoreMems = {};
    end
    
    if ~flag
        %         if ~isempty(dataStoreMems)
        %             mem = dataStoreMems{1};
        %         else
        %             mem = dataStoreMems;
        %         end
        mem = dataStoreMems;
        return
    end
    
    level = get_param(block, 'parent');
    currentLevel = '';
    
    % Level of the Data Store Read/Write being split into subsystem name tokens
    levelSplit = regexp(level, '/', 'split');
    
    for i = 1:length(dataStoreMems)
        % Get level of subsystem for the Data Store Memory
        memScope = get_param(dataStoreMems{i}, 'parent');
        memScopeSplit = regexp(memScope, '/', 'split');
        inter = memScopeSplit(ismember(memScopeSplit, levelSplit));
        % Check if the Data Store Memory is above the write in system hierarchy
        if (length(inter) == length(memScopeSplit))
            currentLevelSplit = regexp(currentLevel, '/', 'split');
            % If it is closest to the Read/Write, note that as the correct
            % scope for the Data Store Memory block
            if isempty(currentLevel) || length(currentLevelSplit) < length(memScopeSplit)
                currentLevel = memScope;
            end
        end
    end
    
    if ~isempty(currentLevel)
        mem = find_system(currentLevel, 'FollowLinks', 'on', 'SearchDepth', 1, ...
            'BlockType', 'DataStoreMemory', 'DataStoreName', dataStoreName);
        %         mem = mem{1};
    else
        mem = {};
    end
end
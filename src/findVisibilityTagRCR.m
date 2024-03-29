function visBlock = findVisibilityTagRCR(obj, block, flag)
    % FINDVISIBILITYTAG Find the Goto Visibility Tag block associated with a
    % scoped Goto or From block.
    %
    % 	Inputs:
    % 		obj         The reachcoreach object containing goto tag mappings.
    %       block       The goto or from block of interest as a char array, an
    %                   empty cell array, or a 1x1 cell array containing the
    %                   block as a char array.
    %       flag        The flag indicating whether shadowing goto tags are in
    %                   the model.
    %
    % 	Outputs:
    %		visBlock  The tag visibility block corresponding to input "block".
    %
    
    % Input Handling:
    if iscell(block) && ~isempty(block)
        assert(length(block) == 1, 'Something went wrong, block input too long.')
        block = block{1};
    end
    
    %
    if isempty(block)
        visBlock = {};
        return
    end
    
    % Ensure input is a valid Goto/From block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'Goto') || strcmp(blockType, 'From'));
    catch
        disp(['Error using ' mfilename ':' newline ...
            ' Block parameter is not a Goto or From block.' newline])
        help(mfilename)
        visBlock = {};
        return
    end
    
    %
    if ~isempty(obj.implicitMaps)
        if obj.implicitMaps.gf2v.isKey(block)
            visBlock = obj.implicitMaps.gf2v(block);
            return
        end
    end
    
    %
    tag = get_param(block, 'GotoTag');
    if obj.stvMap.isKey(tag)
        scopedTags = obj.stvMap(tag);
    else
        scopedTags = {};
    end
    
    if ~flag
        %         if ~isempty(scopedTags)
        %             visBlock = scopedTags{1};
        %         else
        %             visBlock = scopedTags;
        %         end
        visBlock = scopedTags;
        return
    end
    
    level = get_param(block, 'parent');
    levelSplit = regexp(level, '/', 'split');
    
    currentLevel = '';
    
    % Find the Goto Tag Visibility block that is the closest, but above the
    % block, in the subsystem hierarchy by comparing their addresses
    for i = 1:length(scopedTags)
        % Get the level of tag visibility block
        tagScope = get_param(scopedTags{i}, 'parent');
        tagScopeSplit = regexp(tagScope, '/', 'split');
        inter = tagScopeSplit(ismember(tagScopeSplit, levelSplit));
        
        % Check if it is above the block
        if (length(inter) == length(tagScopeSplit))
            currentLevelSplit = regexp(currentLevel, '/', 'split');
            % If it is the closest to the Goto/From, note that as the correct
            % scope for the visibility block
            if isempty(currentLevel) || length(currentLevelSplit) < length(tagScopeSplit)
                currentLevel = tagScope;
            end
        end
    end
    
    if ~isempty(currentLevel)
        visBlock = find_system(currentLevel, 'FollowLinks', 'on', ...
            'SearchDepth', 1, 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
        %         visBlock = visBlock{1};
    else
        visBlock = {};
    end
end
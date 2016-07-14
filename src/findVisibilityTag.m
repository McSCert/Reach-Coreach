
function visBlock = findVisibilityTag(block)
%FINDVISIBILITYTAG Function that finds the associated visibility tag of a
%scoped goto or from.

    %make sure input is a valid goto/from block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'Goto') || strcmp(blockType, 'From'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            'Block parameter is not a goto or from block.' char(10)])
        help(mfilename)
        return
    end

    tag = get_param(block, 'GotoTag');
    scopedTags = find_system(bdroot(block), 'FollowLinks', 'on', 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
    level = get_param(block, 'parent');
    levelSplit = regexp(level, '/', 'split');

    currentLevel = '';

    %finds goto tag visibility block with the closest above the block in
    %the subsystem hierarchy by comparing their addresses in loop
    for i = 1:length(scopedTags)
        %get level of tag visibility block
        tagScope = get_param(scopedTags{i}, 'parent');
        tagScopeSplit = regexp(tagScope, '/', 'split');
        inter = intersect(tagScopeSplit, levelSplit);
        
        %check if it's above the block
        if (length(inter) == length(tagScopeSplit))
            currentLevelSplit = regexp(currentLevel, '/', 'split');
            %if it's the closest to the goto/from, note that as the correct
            %scope for the visibility block
            if isempty(currentLevel) || length(currentLevelSplit) < length(tagScopeSplit)
                currentLevel = tagScope;
            end
        end
    end
    
    if ~isempty(currentLevel)
        visBlock = find_system(currentLevel, 'FollowLinks', 'on', 'SearchDepth', 1, 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
        visBlock = visBlock{1};
    else
        visBlock ={};
    end

end

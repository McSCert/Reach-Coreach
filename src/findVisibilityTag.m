
function visBlock = findVisibilityTag(block)
%FINDVISIBILITYTAG Function that finds the associated visibility tag of a
%scoped goto or from.

    tag=get_param(block, 'GotoTag');
    scopedTags=find_system(bdroot(block), 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
    level=get_param(block, 'parent');
    levelSplit=regexp(level, '/', 'split');

    currentLevel=level;

    for i=1:length(scopedTags)
        tagScope=get_param(scopedTags{i}, 'parent');
        tagScopeSplit=regexp(tagScope, '/', 'split');
        inter=intersect(tagScopeSplit, levelSplit);

        if (length(inter)==length(tagScopeSplit))
            currentLevelSplit=regexp(currentLevel, '/', 'split');
            %if it's the closest to the goto, note that as the correct
            %scope for the visibility block
            if length(currentLevelSplit)<length(tagScopeSplit)
                currentLevel=tagScope;
            end
        end
    end
    
    visBlock=find_system(currentLevel, 'SearchDepth', 1, 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
    visBlock=visBlock{1};

end

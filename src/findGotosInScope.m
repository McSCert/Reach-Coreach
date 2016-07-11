function goto=findGotosInScope(block)
%find the corresponding goto to a from block
    tag=get_param(block, 'GotoTag');
    goto=find_system(get_param(block, 'parent'), 'BlockType', 'Goto', 'GotoTag', tag, 'TagVisibility', 'local');
    if ~isempty(goto)
        return
    end
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

    % Get the corresponding gotos for a given from that's in the
    % correct scope.
    visibilityBlock=find_system(currentLevel, 'SearchDepth', 1, 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
    goto=findGotoFromsInScope(visibilityBlock{1});
    blocksToExclude=find_system(currentLevel, 'BlockType', 'From', 'GotoTag', tag);
    goto=setdiff(goto, blocksToExclude);
end

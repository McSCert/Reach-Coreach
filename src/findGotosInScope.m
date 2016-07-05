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
    currentLimit='';

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
            %if a visibility tag is below the level of the goto in
            %subsystem hierarchy
        elseif (length(inter)==length(levelSplit))
            currentLimitSplit=regexp(currentLevel, '/', 'split');
            if length(currentLimitSplit)<length(tagScopeSplit)
                currentLimit=tagScope;
            end
        end
    end

    % Get the corresponding gotos for a given from that's in the
    % correct scope.
    goto=find_system(currentLevel, 'BlockType', 'Goto', 'GotoTag', tag);
    gotosToExclude=find_system(currentLimit, 'BlockType', 'Goto', 'GotoTag', tag);
    goto=setdiff(goto, gotosToExclude);
end

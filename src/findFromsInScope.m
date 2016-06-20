function froms=findFromsInScope(block)
    %function for finding all of the from blocks for a
    %corresponding goto
    tag=get_param(block, 'GotoTag');
    scopedTags=find_system(bdroot(block), 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
    level=get_param(block, 'parent');
    %if there are no corresponding tags, goto is assumed to be
    %local, and all local froms corresponding to the tag are found
    if isempty(scopedTags)
        froms=find_system(level, 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', tag);
        return
    end

    %currentLevel is the current assumed level of the scope of the
    %goto
    currentLevel=level;
    currentLimit='';

    %declaration of the level of the goto being split into
    %subsystem name tokens
    levelSplit=regexp(currentLevel, 'split', '/');

    for i=1:length(scopedTags)
        %get level of subsystem for visibility tag
        tagScope=get_param(scopedTags(i), 'parent');
        tagScopeSplit=regexp(tagScope, '/', 'split');
        inter=intersect(tagScopeSplit, levelSplit);
        %check if the visibility tag is above the goto in subsystem
        %hierarchy
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
    %get all froms within the scope of the tag selected goto
    %belongs to
    froms=find_system(currentLevel, 'BlockType', 'From', 'GotoTag', tag);
    fromsToExclude=find_system(currentLimit, 'BlockType', 'From', 'GotoTag', tag);
    froms=setdiff(froms, fromsToExclude);
end

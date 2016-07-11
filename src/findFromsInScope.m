function froms=findFromsInScope(block)
    %function for finding all of the from blocks for a
    %corresponding goto
    tag=get_param(block, 'GotoTag');
    scopedTags=find_system(bdroot(block), 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
    level=get_param(block, 'parent');
    tagVis=get_param(block, 'TagVisibility');
    %if there are no corresponding tags, goto is assumed to be
    %local, and all local froms corresponding to the tag are found
    if strcmp(tagVis, 'local')
        froms=find_system(level, 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', tag);
        return
    elseif strcmp(tagVis, 'scoped');
        
        %currentLevel is the current assumed level of the scope of the
        %goto
        currentLevel=level;
        
        %declaration of the level of the goto being split into
        %subsystem name tokens
        levelSplit=regexp(currentLevel, '/', 'split');
        
        for i=1:length(scopedTags)
            %get level of subsystem for visibility tag
            tagScope=get_param(scopedTags{i}, 'parent');
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
            end
        end
        %get all froms within the scope of the tag selected goto
        %belongs to
        visibilityBlock=find_system(currentLevel, 'SearchDepth', 1, 'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
        froms=findGotoFromsInScope(visibilityBlock);
        blocksToExclude=find_system(currentLevel, 'BlockType', 'Goto', 'GotoTag', tag);
        froms=setdiff(froms, blocksToExclude);
    else
        fromsToExclude={};
        for i=1:length(scopedTags)
            fromsToExclude=[fromsToExclude find_system(get_param(scopedTags{i}, 'parent'), ...
                'BlockType', 'From', 'GotoTag', tag)];
        end
        localGotos=find_system(bdroot(block), 'BlockType', 'Goto', 'TagVisibility', 'local');
        for i=1:length(localGotos)
            fromsToExclude=[fromsToExclude find_system(get_param(localGotos{i}, 'parent'), ...
                'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', tag)];
        end
        froms=find_system(bdroot(block), 'BlockType', 'From', 'GotoTag', tag);
        froms=setdiff(froms, fromsToExclude);
    end
end

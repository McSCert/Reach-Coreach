function froms=findFromsInScope(block)
    %FINDFROMSINSCOPE function for finding all associated froms for a goto
    %block
    
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
        visibilityBlock=findVisibilityTag(block);
        froms=findGotoFromsInScope(visibilityBlock);
        blocksToExclude=find_system(get_param(visibilityBlock, 'parent'), 'BlockType', 'Goto', 'GotoTag', tag);
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

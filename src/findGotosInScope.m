function goto=findGotosInScope(block)
%FINDGOTOSINSCOPE function that finds associated goto for a from block
    tag=get_param(block, 'GotoTag');
    goto=find_system(get_param(block, 'parent'), 'FollowLinks', 'on', 'BlockType', 'Goto', 'GotoTag', tag, 'TagVisibility', 'local');
    if ~isempty(goto)
        return
    end
    
    % Get the corresponding gotos for a given from that's in the
    % correct scope.
    visibilityBlock=findVisibilityTag(block);
    if isempty(visibilityBlock)
        goto=find_system(bdroot(block), 'FollowLinks', 'on', 'BlockType', 'Goto', 'GotoTag', tag, 'TagVisibility', 'global');
        return
    end
    goto=findGotoFromsInScope(visibilityBlock);
    blocksToExclude=find_system(get_param(visibilityBlock, 'parent'), 'FollowLinks', 'on', 'BlockType', 'From', 'GotoTag', tag);
    goto=setdiff(goto, blocksToExclude);
end

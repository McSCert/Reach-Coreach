function goto=findGotosInScope(block)
%FINDGOTOSINSCOPE function that finds associated goto for a from block
    tag=get_param(block, 'GotoTag');
    goto=find_system(get_param(block, 'parent'), 'BlockType', 'Goto', 'GotoTag', tag, 'TagVisibility', 'local');
    if ~isempty(goto)
        return
    end
    
    % Get the corresponding gotos for a given from that's in the
    % correct scope.
    visibilityBlock=findVisibilityTag(block);
    goto=findGotoFromsInScope(visibilityBlock);
    blocksToExclude=find_system(get_param(visibilityBlock, 'parent'), 'BlockType', 'From', 'GotoTag', tag);
    goto=setdiff(goto, blocksToExclude);
end

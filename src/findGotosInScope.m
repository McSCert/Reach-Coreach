function goto=findGotosInScope(block)
%FINDGOTOSINSCOPE function that finds associated goto for a from block

    %make sure block parameter is a valid from block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType=get_param(block, 'BlockType');
        assert(strcmp(blockType, 'From'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            'Block parameter is not a from block.' char(10)])
        help(mfilename)
        return
    end
    
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

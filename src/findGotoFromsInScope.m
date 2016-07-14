function blockList = findGotoFromsInScope(block)
%FINDGOTOFROMSINSCOPE This function finds all the associated goto and from
%blocks of a goto tag visibility block

    %make sure input is a valid goto tag visibility block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'GotoTagVisibility'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            'Block parameter is not a goto tag visibility block.' char(10)])
        help(mfilename)
        return
    end
    
    %get all other goto tag visibility blocks
    gotoTag = get_param(block, 'GotoTag');
    blockParent = get_param(block, 'parent');
    tagsSameName = find_system(blockParent, 'FollowLinks', 'on', 'BlockType', 'GotoTagVisibility', 'GotoTag', gotoTag);
    tagsSameName = setdiff(tagsSameName, block);
    
    %any goto/from blocks in their scopes are listed as blocks not in the
    %input goto tag visibility block's scope
    blocksToExclude ={};
    for i = 1:length(tagsSameName)
        tagParent = get_param(tagsSameName{i}, 'parent');
        blocksToExclude = [blocksToExclude; find_system(tagParent, 'FollowLinks', 'on', 'BlockType', 'From', 'GotoTag', gotoTag)];
        blocksToExclude = [blocksToExclude; find_system(tagParent, 'FollowLinks', 'on', 'BlockType', 'Goto', 'GotoTag', gotoTag)];
    end
    
    % all froms associated with local gotos are listed as blocks not in the scope of input
    %goto tag visibility block
    localGotos = find_system(blockParent, 'FollowLinks', 'on', 'BlockType', 'Goto', 'GotoTag', gotoTag, 'TagVisibility', 'local');
    for i = 1:length(localGotos)
        froms = find_system(get_param(localGotos{i}, 'parent'), 'FollowLinks', 'on', 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', gotoTag);
        blocksToExclude = [blocksToExclude; localGotos{i}; froms];
    end
    
    %removes all listed blocks to exclude
    blockList = find_system(blockParent, 'FollowLinks', 'on', 'BlockType', 'From', 'GotoTag', gotoTag);
    blockList = [blockList; find_system(blockParent, 'FollowLinks', 'on', 'BlockType', 'Goto', 'GotoTag', gotoTag)];
    blockList = setdiff(blockList, blocksToExclude);

end


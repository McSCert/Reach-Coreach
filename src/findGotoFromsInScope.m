function blockList = findGotoFromsInScope(block)
%FINDGOTOFROMSINSCOPE This function finds all the associated goto and from
%blocks of a goto tag visibility block
    
    %get all other goto tag visibility blocks
    gotoTag=get_param(block, 'GotoTag');
    blockParent=get_param(block, 'parent');
    tagsSameName=find_system(blockParent, 'BlockType', 'GotoTagVisibility', 'GotoTag', gotoTag);
    tagsSameName=setdiff(tagsSameName, block);
    
    %any goto/from blocks in their scopes are listed as blocks not in the
    %input goto tag visibility block's scope
    blocksToExclude={};
    for i=1:length(tagsSameName)
        tagParent=get_param(tagsSameName{i}, 'parent');
        blocksToExclude=[blocksToExclude; find_system(tagParent, 'BlockType', 'From', 'GotoTag', gotoTag)];
        blocksToExclude=[blocksToExclude; find_system(tagParent, 'BlockType', 'Goto', 'GotoTag', gotoTag)];
    end
    
    % all froms associated with local gotos are listed as blocks not in the scope of input
    %goto tag visibility block
    localGotos=find_system(blockParent, 'BlockType', 'Goto', 'GotoTag', gotoTag, 'TagVisibility', 'local');
    for i=1:length(localGotos)
        froms=find_system(get_param(localGotos{i}, 'parent'), 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', gotoTag);
        blocksToExclude=[blocksToExclude; localGotos{i}; froms];
    end
    
    %removes all listed blocks to exclude
    blockList=find_system(blockParent, 'BlockType', 'From', 'GotoTag', gotoTag);
    blockList=[blockList; find_system(blockParent, 'BlockType', 'Goto', 'GotoTag', gotoTag)];
    blockList=setdiff(blockList, blocksToExclude);

end


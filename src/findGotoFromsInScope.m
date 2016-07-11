function blockList = findGotoFromsInScope(block)
%FINDGOTOFROMSINSCOPE This function finds all the associated goto and from
%blocks of a goto tag visibility block

    gotoTag=get_param(block, 'GotoTag');
    blockParent=get_param(block, 'parent');
    tagsSameName=find_system(parent, 'BlockType', 'GotoTagVisibility', 'GotoTag', gotoTag);
    tagsSameName=setdiff(tagsSameName, block);
    
    blocksToExclude={};
    for i=1:length(tagsSameName)
        tagParent=get_param(tagsSameName{i}, 'parent');
        blocksToExclude=[blocksToExclude; find_system(tagParent, 'BlockType', 'From', 'GotoTag', gotoTag)];
        blocksToExclude=[blocksToExclude; find_system(tagParent, 'BlockType', 'Goto', 'GotoTag', gotoTag)];
    end
    
    localGotos=find_system(blockParent, 'BlockType', 'Goto', 'GotoTag', gotoTag, 'TagVisibility', 'local');
    for i=1:length(localGotos)
        froms=find_system(get_param(localGotos{i}, 'parent'), 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', gotoTag);
        blocksToExclude=[blocksToExclude; localGotos{i}; froms];
    end
    
    blockList=find_system(blockParent, 'BlockType', 'From', 'GotoTag', gotoTag);
    blockList=[blockList; find_system(blockParent, 'BlockType', 'Goto', 'GotoTag', gotoTag)];
    blockList=setdiff(blockList, blocksToExclude);

end


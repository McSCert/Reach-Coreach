function blockList = findGotoFromsInScopeRCR(obj, block, flag)
    % FINDGOTOFROMSINSCOPE Find all the Goto and From blocks associated with a
    % Goto Tag Visibility block.
    %
    % 	Inputs:
    % 		obj         The reachcoreach object containing goto tag mappings.
    %       block       The tag visibility block of interest as a char array, an
    %                   empty cell array, or a 1x1 cell array containing the
    %                   block as a char array.
    %       flag        The flag indicating whether shadowing visibility tags
    %                   are in the model.
    %
    % 	Outputs:
    %		blockList   Cell array of goto/from blocks corresponding to input
    %                   "block".
    %
    
    % Input Handling:
    if iscell(block) && ~isempty(block)
        assert(length(block) == 1, 'Something went wrong, block input too long.')
        block = block{1};
    end
    
    %
    if isempty(block)
        blockList = {};
        return
    end
    
    % Ensure input is a valid Goto Tag Visibility block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'GotoTagVisibility'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            ' Block parameter is not a Goto Tag Visibility block.' char(10)])
        help(mfilename)
        blockList = {};
        return
    end
    
    %
    if ~isempty(obj.implicitMaps)
        if obj.implicitMaps.v2gf.isKey(block)
            blockList = obj.implicitMaps.v2gf(block);
            return
        end
    end
    
    % Get all other Goto Tag Visibility blocks
    gotoTag = get_param(block, 'GotoTag');
    
    if ~flag
        blockList = [];
        if obj.sfMap.isKey(gotoTag)
            blockList = [blockList; obj.sfMap(gotoTag)];
        end
        if obj.sgMap.isKey(gotoTag)
            blockList = [blockList; obj.sgMap(gotoTag)];
        end
        return
    end
    
    blockParent = get_param(block, 'parent');
    if obj.stvMap.isKey(gotoTag)
        tagsSameName = obj.stvMap(gotoTag);
    else
        tagsSameName = {};
    end
    tagsSameName = setdiff(tagsSameName, block);
    
    % Any Goto/From blocks in their scopes are listed as blocks not in the
    % input Goto Tag Visibility block's scope
    blocksToExclude = {};
    for i = 1:length(tagsSameName)
        tagFlag = 0;
        tagParent = get_param(tagsSameName{i}, 'parent');
        if length(tagParent) > length(blockParent)
            if strcmp(blockParent, tagParent(1:length(blockParent)))
                tagFlag = 1;
            end
        end
        if tagFlag
            tagParent = get_param(tagsSameName{i}, 'parent');
            blocksToExclude = [blocksToExclude; find_system(tagParent, ...
                'FollowLinks', 'on', 'BlockType', 'From', 'GotoTag', gotoTag)];
            blocksToExclude = [blocksToExclude; find_system(tagParent, ...
                'FollowLinks', 'on', 'BlockType', 'Goto', 'GotoTag', gotoTag)];
        end
    end
    % All Froms associated with local Gotos are listed as blocks not in the
    % scope of input Goto Tag Visibility block
    localGotos = find_system(blockParent, 'FollowLinks', 'on', ...
        'BlockType', 'Goto', 'GotoTag', gotoTag, 'TagVisibility', 'local');
    for i = 1:length(localGotos)
        froms = find_system(get_param(localGotos{i}, 'parent'), ...
            'FollowLinks', 'on', 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', gotoTag);
        blocksToExclude = [blocksToExclude; localGotos{i}; froms];
    end
    
    % Remove all excluded blocks
    blockList = find_system(blockParent, 'FollowLinks', 'on', ...
        'BlockType', 'From', 'GotoTag', gotoTag);
    blockList = [blockList; find_system(blockParent, 'FollowLinks', 'on', ...
        'BlockType', 'Goto', 'GotoTag', gotoTag)];
    blockList = setdiff(blockList, blocksToExclude);
end
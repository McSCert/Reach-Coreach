function froms = findFromsInScopeRCR(obj, block, flag)
% FINDFROMSINSCOPE Find all the From blocks associated with a Goto block.

    if isempty(block)
        froms = {};
        return
    end
    
    % Ensure block parameter is a valid Goto block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'Goto'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            ' Block parameter is not a Goto block.' char(10)])
        help(mfilename)
        froms = {};
        return
    end
    
    tag = get_param(block, 'GotoTag');
    tagVis = get_param(block, 'TagVisibility');
    level = get_param(block, 'parent');
    
    if flag
        if strcmp(tagVis, 'local')
            froms = find_system(level, 'FollowLinks', 'on', 'SearchDepth', 1, ...
                'BlockType', 'From', 'GotoTag', tag);
            return
        else
            if isKey(obj.sfMap, tag)
                froms = obj.sfMap(tag);
            else
                froms = {};
            end
            return
        end
    end
    
    scopedTags = find_system(bdroot(block), 'FollowLinks', 'on', ...
        'BlockType', 'GotoTagVisibility', 'GotoTag', tag);

    % If there are no corresponding tags, Goto is assumed to be
    % local, and all local Froms corresponding to the tag are found
    if strcmp(tagVis, 'local')
        froms = find_system(level, 'FollowLinks', 'on', 'SearchDepth', 1, ...
            'BlockType', 'From', 'GotoTag', tag);
        return
    elseif strcmp(tagVis, 'scoped');
        visibilityBlock = findVisibilityTagBD(block);
        froms = findGotoFromsInScopeRCR(visibilityBlock);
        if isKey(obj.sfMap, tag)
            blocksToExclude = obj.sgMap(tag);
        else
            blocksToExclude = {};
        end
        froms = setdiff(froms, blocksToExclude);
    else
        %the global goto case: very slow
        fromsToExclude = {};

        for i = 1:length(scopedTags)
            if isKey(obj.sfMap, tag)
                temp = obj.sgMap(tag);
            else
                temp = {};
            end
            fromsToExclude = [fromsToExclude temp];
        end

        localGotos = find_system(bdroot(block), 'BlockType', 'Goto', 'TagVisibility', 'local');
        for i = 1:length(localGotos)
            fromsToExclude = [fromsToExclude find_system(get_param(localGotos{i}, 'parent'), ...
                'SearchDepth', 1, 'FollowLinks', 'on', 'BlockType', 'From', 'GotoTag', tag)];
        end
        
        froms = find_system(bdroot(block), 'FollowLinks', 'on', ...
            'BlockType', 'From', 'GotoTag', tag);
        froms = setdiff(froms, fromsToExclude);
    end
end
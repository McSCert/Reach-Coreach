function froms = findFromsInScopeRCR(obj, block, flag)
    % FINDFROMSINSCOPE Find all the From blocks associated with a Goto block.
    %
    % 	Inputs:
    % 		obj     The reachcoreach object containing goto tag mappings.
    %       block   The goto block of interest as a char array, an empty cell
    %               array, or a 1x1 cell array containing the block as a char
    %               array.
    %       flag    The flag indicating whether shadowing visibility tags are in
    %               the model.
    %
    % 	Outputs:
    %		froms   The tag visibility block corresponding to input "block".
    %
    
    % Input Handling:
    if iscell(block) && ~isempty(block)
        assert(length(block) == 1, 'Something went wrong, block input too long.')
        block = block{1};
    end
    
    %
    if isempty(block)
        froms = {};
        return
    end
    
    % Ensure block input is a valid Goto block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'Goto'));
    catch
        disp(['Error using ' mfilename ':' newline ...
            ' Block parameter is not a Goto block.' newline])
        help(mfilename)
        froms = {};
        return
    end
    
    %
    if ~isempty(obj.implicitMaps)
        if obj.implicitMaps.g2f.isKey(block)
            froms = obj.implicitMaps.g2f(block);
            return
        end
    end
    
    %
    tag = get_param(block, 'GotoTag');
    tagVis = get_param(block, 'TagVisibility');
    level = get_param(block, 'parent');
    
    if ~flag
        if strcmp(tagVis, 'local')
            froms = find_system(level, 'FollowLinks', 'on', 'SearchDepth', 1, ...
                'BlockType', 'From', 'GotoTag', tag);
            return
        else
            if obj.sfMap.isKey(tag)
                froms = obj.sfMap(tag);
            else
                froms = {};
            end
            return
        end
    end
    
    scopedTags = find_system(bdroot(block), 'FollowLinks', 'on', ...
        'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
    
    if isempty(scopedTags)
        scopedTags = find_system(bdroot(block), 'LookUnderMasks','on', 'FollowLinks', 'on', ...
        'BlockType', 'GotoTagVisibility', 'GotoTag', tag);
    end
    
    % If there are no corresponding tags, Goto is assumed to be
    % local, and all local Froms corresponding to the tag are found
    if strcmp(tagVis, 'local')
        froms = find_system(level, 'FollowLinks', 'on', 'SearchDepth', 1, ...
            'BlockType', 'From', 'GotoTag', tag);
        if isempty(scopedTags)
            froms = find_system(level, 'LookUnderMasks','on', 'FollowLinks', 'on', 'SearchDepth', 1, ...
                'BlockType', 'From', 'GotoTag', tag);
        end
        return
    elseif strcmp(tagVis, 'scoped')
        visibilityBlock = findVisibilityTagRCR(obj, block, flag);
        froms = findGotoFromsInScopeRCR(obj, visibilityBlock, flag);
        if obj.sfMap.isKey(tag)
            % TODO: Why is sgMap used here? Is tag guaranteed to be a key?
            % If it's not a key is it correct to set blocksToExclude = {}.
            if obj.sgMap.isKey(tag)
                blocksToExclude = obj.sgMap(tag);
            else
                blocksToExclude = {};
            end
        else
            blocksToExclude = {};
        end
        froms = setdiff(froms, blocksToExclude);
    else
        %the global goto case: very slow
        fromsToExclude = {};
        
        for i = 1:length(scopedTags)
            if obj.sfMap.isKey(tag)
                % TODO: Why is sgMap used here? Is tag guaranteed to be a key?
                % If it's not a key is it correct to set temp = {}.
                if obj.sgMap.isKey(tag)
                    temp = obj.sgMap(tag);
                else
                    temp = {};
                end
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
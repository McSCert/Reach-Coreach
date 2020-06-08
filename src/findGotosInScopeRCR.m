function goto = findGotosInScopeRCR(obj, block, flag)
    % FINDGOTOSINSCOPE Find the Goto block associated with a From block.
    %
    % 	Inputs:
    % 		obj     The reachcoreach object containing goto tag mappings.
    %       block   The from block of interest as a char array, an empty cell
    %               array, or a 1x1 cell array containing the block as a char
    %               array.
    %       flag    The flag indicating whether shadowing visibility tags are in
    %               the model.
    %
    % 	Outputs:
    %		goto    The goto block corresponding to input "block".
    %
    
    % Input Handling:
    if iscell(block) && ~isempty(block)
        assert(length(block) == 1, 'Something went wrong, block input too long.')
        block = block{1};
    end
    
    % if no gotos are found, return an empty list
    goto = {};
    
    if isempty(block)
        return
    end
    
    % Ensure block parameter is a valid From block
    try
        assert(strcmp(get_param(block, 'type'), 'block'));
        blockType = get_param(block, 'BlockType');
        assert(strcmp(blockType, 'From'));
    catch
        disp(['Error using ' mfilename ':' char(10) ...
            ' Block parameter is not a From block.' char(10)])
        help(mfilename)
        goto = {};
        return
    end
    
    %
    if ~isempty(obj.implicitMaps)
        if obj.implicitMaps.f2g.isKey(block)
            goto = obj.implicitMaps.f2g(block);
            return
        end
    end
    
    %
    tag = get_param(block, 'GotoTag');
    level = get_param(block, 'parent');
    
    if ~flag
        goto = find_system(level, 'FollowLinks', 'on', 'SearchDepth', 1, ...
            'BlockType', 'Goto', 'GotoTag', tag);
        if isempty(goto)
            if obj.sgMap.isKey(tag)
                goto = obj.sgMap(tag);
            else
                goto = {};
            end
            return
        end
    end
    
    goto = find_system(get_param(block, 'parent'),'SearchDepth', 1,  ...
        'FollowLinks', 'on', 'BlockType', 'Goto', 'GotoTag', tag, 'TagVisibility', 'local');
    if ~isempty(goto)
        return
    end
    
    % Get the corresponding Gotos for a given From that are in the
    % correct scope
    fromParent = get_param(block, 'parent');
    if obj.sgMap.isKey(tag)
        candidateGotos = obj.sgMap(tag);
    else
        candidateGotos = [];
    end
    for i=1:length(candidateGotos)
        gotoParent = get_param(candidateGotos{i}, 'parent');
        switch get_param(candidateGotos{i}, 'TagVisibility')
            case 'local'
                if strcmp(fromParent, gotoParent)
                    % local gotos have highest priority
                    goto = candidateGotos(i);
                    return
                end
            case 'global'
                if isempty(goto)
                    % if another candidate goto hasn't been found to be
                    % acceptable, its goto is global
                    goto = candidateGotos(i);
                end
            otherwise
                %otherwise, find the correctly scoped visibility block for
                %the goto and pick the corresponding goto
                visibilityBlock = findVisibilityTagRCR(obj, block, flag);
                if isempty(visibilityBlock)
                    goto = {};
                else
                    goto = findGotoFromsInScopeRCR(obj, visibilityBlock{1}, flag);
                end
                if obj.sfMap.isKey(tag)
                    blocksToExclude = obj.sfMap(tag);
                else
                    blocksToExclude = {};
                end
                goto = setdiff(goto, blocksToExclude);
        end
    end
end
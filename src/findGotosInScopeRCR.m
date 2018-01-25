function goto = findGotosInScopeRCR(obj, block, flag)
% FINDGOTOSINSCOPE Find the Goto block associated with a From block.

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
    
    tag = get_param(block, 'GotoTag');
    
    if flag
        try
            goto = obj.sgMap(tag);
        catch
            goto = {};
        end
        return
    end
    
    goto = find_system(get_param(block, 'parent'),'SearchDepth', 1,  ...
        'FollowLinks', 'on', 'BlockType', 'Goto', 'GotoTag', tag, 'TagVisibility', 'local');
    if ~isempty(goto)
        return
    end
    
    % Get the corresponding Gotos for a given From that are in the
    % correct scope
    fromParent = get_param(block, 'parent');
    candidateGotos = obj.sgMap(tag);
    for i=1:length(candidateGotos)
        gotoParent = get_param(candidateGotos{i}, 'parent');
        switch get_param(candidateGotos{i}, 'TagVisibility');
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
                visibilityBlock = findVisibilityTagRCR(obj, block,flag);
                goto = findGotoFromsInScopeRCR(obj, visibilityBlock, flag);
                blocksToExclude = obj.sfMap(tag);
                goto = setdiff(goto, blocksToExclude);
        end
    end
end
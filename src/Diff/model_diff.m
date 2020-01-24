function diffStruct = model_diff(oldModel, newModel, diffTree)
    % MODEL_DIFF Performs a diff between 2 models and gets changes to blocks,
    % lines, and ports.
    %
    % Inputs:
    %   oldModel    Simulink model.
    %   newModel    Simulink model to treat as an updated version of
    %               oldModel.
    %   diffTree    [Optional] Result of:
    %                   slxmlcomp.compare(oldModel,newModel)
    %               Only used to speed up results.
    %
    % Outputs:
    % 	diffStruct  Struct containing all blocks, lines, and ports that have
    %               changed between oldModel and newModel. The fields are
    %               explained below.
    %       diffStruct.comparisonRoot - xmlcomp.Edits object representing
    %               the model changes using MATLAB's built-in structure.
    %       diffStruct.blocks - Struct used to list the changed blocks.
    %           diffStruct.blocks.add - Struct used to list the added blocks.
    %                   diffStruct.blocks.add.new - Cell array of blocks added
    %                           to the new model.
    %                   diffStruct.blocks.add.old - Cell array of blocks added
    %                           to the old model (note this should always be
    %                           empty, but is here for consistency in the
    %                           diffStruct field structure e.g.
    %                           diffStruct.blocks.del.old is not always empty).
    %                   diffStruct.blocks.add.all - Cell array of blocks added
    %                           to either model.
    %           diffStruct.blocks.del - Struct used to list the deleted blocks;
    %                   has the same field structure as diffStruct.blocks.add.
    %           diffStruct.blocks.mod - Struct used to list the modified blocks;
    %                   has the same field structure as diffStruct.blocks.add.
    %           diffStruct.blocks.mod0 - Struct used to list the modified blocks
    %                   excluding SubSystems just with changed number of ports;
    %                   has the same field structure as diffStruct.blocks.add.
    %           diffStruct.blocks.rename - Struct used to list the renamed
    %                   blocks;
    %                   has the same field structure as diffStruct.blocks.add.
    %       diffStruct.lines - Struct used to list the changed lines;
    %               has the same field structure as diffStruct.blocks.
    %       diffStruct.ports - Struct used to list the changed ports;
    %               has the same field structure as diffStruct.blocks.
    %       diffStruct.notes - Struct used to list the changed annotations;
    %               has the same field structure as diffStruct.blocks.
    %       Note: blocks are ultimately recorded in a cell array, lines and
    %       ports are ultimately recorded in a numeric array.
    %
    
    % Struct template.
    oldNewAll = struct('old', [], 'new', [], 'all', []);
    addDelMod = struct('add', oldNewAll, ...
        'del', oldNewAll, ...
        'mod0', oldNewAll, ... % mod0 does not include subsystems that have only changed in number of ports
        'mod', oldNewAll, ...
        'rename', oldNewAll);
    diffStruct = struct('comparisonRoot', [], ...
        'blocks', addDelMod, ...
        'lines', addDelMod, ...
        'ports', addDelMod, ...
        'notes', addDelMod);
    
    % Get comparison tree.
    if nargin == 2
        assert(~any(strcmp(get_param({oldModel, newModel}, 'Dirty'), 'on')), ...
            'Both models must be saved before model comparison.')
        diffTree = slxmlcomp.compare(oldModel, newModel);
    end
    if ~isempty(diffTree)
        diffStruct.comparisonRoot = diffTree;
        
        % Get nodes of different change types.
        addedNodes = find_node(diffTree, 'ChangeType', 'added');
        deletedNodes = find_node(diffTree, 'ChangeType', 'deleted');
        modifiedNodes = find_node(diffTree, 'ChangeType', 'modified');
        renamedNodes = find_node(diffTree, 'ChangeType', 'renamed');
        
        mod0Nodes = modifiedNodes(arrayfun(@(node) isModified(node, 0), modifiedNodes)); % Remove subsystems that have only changed in number of ports
        mod1Nodes = modifiedNodes(arrayfun(@(node) isModified(node, 1), modifiedNodes));
        assert(isempty(setdiff(mod1Nodes, modifiedNodes))) % All modified nodes should return true for isModified(node, 1)
        
        % Record changed blocks, lines, and ports.
        for j = {{'add', addedNodes}, {'del', deletedNodes}, ...
                {'mod0', mod0Nodes}, {'mod', mod1Nodes}, {'rename', renamedNodes}}
            chType = j{1}{1}; % Type of change
            nodes = j{1}{2}; % Nodes with that type of change
            
            % Record in the 'old' and 'new' fields.
            for k = {{'old', oldModel}, {'new', newModel}}
                version = k{1}{1};
                mdl = k{1}{2};
                
                % Get the objects.
                [bs, ls, ps, ns] = get_node_objects(nodes, mdl);
                
                % Record the objects.
                diffStruct.('blocks').(chType).(version) = bs;
                diffStruct.('lines').(chType).(version) = ls;
                diffStruct.('ports').(chType).(version) = ps;
                diffStruct.('notes').(chType).(version) = ns;
            end
            
            % Record in the 'all' field.
            for i = {'blocks', 'lines', 'ports', 'notes'}
                obType = i{1}; % Type of object
                
                if isempty(diffStruct.(obType).(chType).old)
                    diffStruct.(obType).(chType).all = diffStruct.(obType).(chType).new;
                elseif isempty(diffStruct.(obType).(chType).new)
                    diffStruct.(obType).(chType).all = diffStruct.(obType).(chType).old;
                else
                    diffStruct.(obType).(chType).all = ...
                        [diffStruct.(obType).(chType).old, diffStruct.(obType).(chType).new];
                end
            end
        end
        
        for i = {'blocks', 'lines', 'ports', 'notes'}
            obType = i{1}; % Type of object
            if false
                assert(isempty(diffStruct.(obType).del.new), ...
                    'Something went wrong. Impossible to have a deleted object in the new model.')
                assert(isempty(diffStruct.(obType).add.old), ...
                    'Something went wrong. Impossible to have a added object in the old model.')
            else
                if ~isempty(diffStruct.(obType).del.new)
                    warning('Something went wrong. Impossible to have a deleted object in the new model.')
                end
                if ~isempty(diffStruct.(obType).add.old)
                    warning('Something went wrong. Impossible to have a added object in the old model.')
                end
%                 if strcmp(obType, 'blocks')
%                     for j = length(diffStruct.(obType).del.new):-1:1
%                         if any(strcmp(get_param(diffStruct.(obType).del.new{j}, 'Name'), {'Hysteresis1', 'Hysteresis2'})) ...
%                                 || any(strcmp(get_param(get_param(diffStruct.(obType).del.new{j}, 'Parent'), 'Name'), {'Hysteresis1', 'Hysteresis2'}))
%                             diffStruct.(obType).del.new(j) = [];
%                         end
%                     end
%                     for j = length(diffStruct.(obType).del.old):-1:1
%                         if any(strcmp(get_param(diffStruct.(obType).del.old{j}, 'Name'), {'Hysteresis1', 'Hysteresis2'})) ...
%                                 || any(strcmp(get_param(get_param(diffStruct.(obType).del.old{j}, 'Parent'), 'Name'), {'Hysteresis1', 'Hysteresis2'}))
%                             diffStruct.(obType).del.old(j) = [];
%                         end
%                     end
%                     for j = 1:length(diffStruct.(obType).add.old)
%                         
%                     end
%                 end
            end
        end
        
        %     % Record changed blocks, lines, and ports in the 'all' field of
        %     % changesStruct.
        %     objectTypes = fields(changesStruct); % {'comparisonRoot', 'blocks', 'lines', 'ports'}
        %     for i = 1:length(objectTypes)
        %         if ~strcmp(objectTypes{i}, 'comparisonRoot')
        %             changeTypes = fields(changesStruct.(objectTypes{i}));
        %             for j = 1:length(changeTypes)
        %                 tmpVector = vector_cat(...
        %                     changesStruct.(objectTypes{i}).(changeTypes{j}).old, ...
        %                     changesStruct.(objectTypes{i}).(changeTypes{j}).new);
        %                 changesStruct.(objectTypes{i}).(changeTypes{j}).all = tmpVector;
        %             end
        %         end
        %     end
        
        %     [bs, ls, ps] = get_node_objects(addedNodes, oldModel);
        %     changesStruct.blocks.add.old = bs;
        %     changesStruct.lines.add.old = ls;
        %     changesStruct.ports.add.old = ps;
        %     [bs, ls, ps] = get_node_objects(addedNodes, newModel);
        %     changesStruct.blocks.add.new = bs;
        %     changesStruct.lines.add.new = ls;
        %     changesStruct.ports.add.new = ps;
        %     [bs, ls, ps] = get_node_objects(deletedNodes, oldModel);
        %     changesStruct.blocks.del.old = bs;
        %     changesStruct.lines.del.old = ls;
        %     changesStruct.ports.del.old = ps;
        %     [bs, ls, ps] = get_node_objects(deletedNodes, newModel);
        %     changesStruct.blocks.del.new = bs;
        %     changesStruct.lines.del.new = ls;
        %     changesStruct.ports.del.new = ps;
        %     [bs, ls, ps] = get_node_objects(renamedNodes, oldModel);
        %     changesStruct.blocks.rename.old = bs;
        %     changesStruct.lines.rename.old = ls;
        %     changesStruct.ports.rename.old = ps;
        %     [bs, ls, ps] = get_node_objects(renamedNodes, newModel);
        %     changesStruct.blocks.rename.new = bs;
        %     changesStruct.lines.rename.new = ls;
        %     changesStruct.ports.rename.new = ps;
        %
        %     [bs, ls, ps] = get_node_objects(mod0Nodes, oldModel);
        %     changesStruct.blocks.mod0.old = bs;
        %     changesStruct.lines.mod0.old = ls;
        %     changesStruct.ports.mod0.old = ps;
        %     [bs, ls, ps] = get_node_objects(mod0Nodes, newModel);
        %     changesStruct.blocks.mod0.new = bs;
        %     changesStruct.lines.mod0.new = ls;
        %     changesStruct.ports.mod0.new = ps;
        %     [bs, ls, ps] = get_node_objects(mod1Nodes, oldModel);
        %     changesStruct.blocks.mod.old = bs;
        %     changesStruct.lines.mod.old = ls;
        %     changesStruct.ports.mod.old = ps;
        %     [bs, ls, ps] = get_node_objects(mod1Nodes, newModel);
        %     changesStruct.blocks.mod.new = bs;
        %     changesStruct.lines.mod.new = ls;
        %     changesStruct.ports.mod.new = ps;
        
        %     oldAddedBlocks = get_node_objects(addedNodes, oldModel);
        %     newAddedBlocks = get_node_objects(addedNodes, newModel);
        %     oldDeletedBlocks = get_node_objects(deletedNodes, oldModel);
        %     newDeletedBlocks = get_node_objects(deletedNodes, newModel);
        
        %     oldModifiedBlocks0 = getObjects(mod0Nodes, oldModel);
        %     newModifiedBlocks0 = getObjects(mod0Nodes, newModel);
        %     oldModifiedBlocks1 = getObjects(mod1Nodes, oldModel);
        %     newModifiedBlocks1 = getObjects(mod1Nodes, newModel);
        
        %     changesStruct = struct('comparisonRoot', {Edits}, ...
        %         'oldAddedBlocks', {oldAddedBlocks}, ...
        %         'newAddedBlocks', {newAddedBlocks}, ...
        %         'oldDeletedBlocks', {oldDeletedBlocks}, ...
        %         'newDeletedBlocks', {newDeletedBlocks}, ...
        %         'oldModifiedBlocks0', {oldModifiedBlocks0}, ...
        %         'newModifiedBlocks0', {newModifiedBlocks0}, ...
        %         'oldModifiedBlocks1', {oldModifiedBlocks1}, ...
        %         'newModifiedBlocks1', {newModifiedBlocks1});
    end
end

function [blocks, lines, ports, notes] = get_node_objects(nodes, model)
    % GET_NODE_OBJECTS is getHandle for numerous nodes. Returns objects
    % according to their type.
    %
    
    % Find each block in model
    blocks = cell(1, length(nodes));
    lines = zeros(1, length(nodes));
    ports = zeros(1, length(nodes));
    notes = zeros(1, length(nodes));
    for i = 1:length(nodes)
        try
            n = nodes(i);
            switch getNodeType(n)
                case 'block'
                    bh = getHandle(n, model);
                    blocks{i} = getfullname(bh);
                case 'line'
                    h = getHandle(n, model);
                    if ~isempty(h)
                        lines(i) = h;
                    end
                case 'port'
                    h = getHandle(n, model);
                    if ~isempty(h)
                        ports(i) = h;
                    end
                case 'annotation'
                    h = getHandle(n, model);
                    if ~isempty(h)
                        notes(i) = h;
                    end
                case 'mask'
                    % Ignore ???
                case 'unknown'
                    % Ignore ???
                case 'block_diagram'
                    % Ignore ???
                otherwise
                    error(['Unexpected type, ' getNodeType(n) ', of changed handle.']) % If a type triggers this, it probably needs to be accounted for
            end
        catch
        end
    end
    
    % Trim unused elements
    blocks = blocks(cellfun(@(cell) ~isempty(cell), blocks));
    lines = lines(arrayfun(@(x) x ~= 0, lines));
    ports = ports(arrayfun(@(x) x ~= 0, ports));
    notes = notes(arrayfun(@(x) x ~= 0, notes));
end
function prev = getPrevBlock(sourcePort)
    
    block = get_param(sourcePort, 'parent');
    blockType = get_param(block, 'BlockType');
    switch blockType
        case 'From'
            prev = findGotosInScope(block);
        case 'Inport'
            portNum = get_param(block, 'Port');
            parent = get_param(block, 'parent');
            newPort = find_system(get_param(parent, 'parent'), 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'SearchDepth', 1, 'FindAll', 'on', ...
                        'type', 'port', 'parent', parent, 'PortType', 'inport', 'PortNumber', str2num(portNum));
            line = get_param(newPort, 'line');
            prev = get_param(line, 'SrcBlockHandle');
            if strcmp(get_param(prev, 'BlockType'),'SubSystem')
                port = get_param(line, 'SrcPortHandle');
                portNum = get_param(port, 'PortNumber');
                outport = find_system(prev, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                prev = outport;
            end
                          
        otherwise
            line = get_param(sourcePort, 'line');
            prev = get_param(line, 'SrcBlockHandle');
            if strcmp(get_param(prev, 'BlockType'),'SubSystem')
                port = get_param(line, 'SrcPortHandle');
                portNum = get_param(port, 'PortNumber');
                outport = find_system(prev, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'Outport', 'Port', num2str(portNum));
                prev = outport;
            end
    end
    

end


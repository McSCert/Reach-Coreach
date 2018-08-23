function GroundAndTerminatePorts(sys)
    %GROUNDANDTERMINATEPORTS Ground and terminate all unconnected ports in the
    %model.
    %
    % 	Inputs:
    % 		sys     The Simulink system for which to ground and terminate
    %               unconnected ports.
    %
    % 	Outputs:
    %		N/A
    
    % get all ports in the system
    ports = find_system(sys, 'SearchDepth', 1, 'findall', 'on', 'type', 'port');
    numTerms = 0;
    numGrounds = 0;
    
    % Iterate through each port
    for i = 1:length(ports)
        % Check if the port doesn't have a connected line.
        if (get_param(ports(i), 'line') == -1)
            if strcmp(get_param(ports(i), 'PortType'), 'outport')
                
                % Add a terminator if the lineless port is an outport
                term = [];
                flag = true;
                while flag
                    try
                        term = add_block('Built-In/Terminator', [sys '/terminator' num2str(numTerms)]);
                        flag = false;
                    catch
                        numTerms = numTerms + 1;
                    end
                end
                
                % Position the terminator
                refpoint = get_param(ports(i), 'Position');
                set_param(term, 'Position', [(refpoint(1) + 30) (refpoint(2) - 10) (refpoint(1) + 50) (refpoint(2) + 10)])
                
                % Add the line connecting the outport and the terminator
                termPort = get_param(term, 'PortHandles');
                termPort = termPort.Inport;
                add_line(sys, ports(i), termPort);
            else
                
                % Add a ground if the lineless port is any other type of
                % port
                ground = [];
                flag = true;
                while flag
                    try
                        ground = add_block('Built-In/Ground', [sys '/ground' num2str(numGrounds)]);
                        flag = false;
                    catch
                        numGrounds = numGrounds + 1;
                    end
                end
                
                % Position the terminator
                refpoint = get_param(ports(i), 'Position');
                set_param(ground, 'Position', [(refpoint(1) - 50) (refpoint(2) - 10) (refpoint(1) - 30) (refpoint(2) + 10)])
                
                % Add the line connecting the ground to the port
                groundPort = get_param(ground, 'PortHandles');
                groundPort = groundPort.Outport;
                add_line(sys, groundPort, ports(i));
            end
        end
    end
    
end


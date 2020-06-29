function busSignals = getBusCreatorSignals(busCreator)
    %
    
    ph = get_param(busCreator, 'PortHandles');
    sh = get_param(ph.Outport, 'SignalHierarchy');
    busSignals = cell(1, length(sh.Children));
    for i = 1:length(sh.Children)
        busSignals{i} = sh.Children(i).SignalName;
    end
    
end
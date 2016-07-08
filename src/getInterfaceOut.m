function blocks=getInterfaceOut(subsystem)
    blocks={};
    gotos=find_system(subsystem, 'BlockType', 'Goto');
    for i=1:length(gotos)
        froms=findFromsInScope(gotos{i});
    end
    writes=find_system(subsystem, 'BlockType', 'DataStoreWrite');
    for i=1:length(writes)
        reads=findReadsInScope(writes{i});
    end
    implicits=[froms reads];
    for i=1:length(implicits)
        name=getfullname(implicits{i});
        lcs=intersect(name, getfullname(subsystem));
        if ~strcmp(lcs, getfullname(subsystem))
            blocks{end+1}=lcs;
        end
    end
end
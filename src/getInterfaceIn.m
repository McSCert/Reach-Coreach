function blocks=getInterfaceIn(subsystem)
    blocks={};
    gotos={};
    writes={};
    froms=find_system(subsystem, 'BlockType', 'From');
    for i=1:length(froms)
        gotos=findFromsInScope(froms{i});
    end
    reads=find_system(subsystem, 'BlockType', 'DataStoreRead');
    for i=1:length(reads)
        writes=findReadsInScope(reads{i});
    end
    implicits=[gotos writes];
    for i=1:length(implicits)
        name=getfullname(implicits{i});
        lcs=intersect(name, getfullname(subsystem));
        if ~strcmp(lcs, getfullname(subsystem))
            blocks{end+1}=implicits{i};
        end
    end
end
%% Register custom menu function to beginning of Simulink Editor's context menu
function sl_customization(cm)
    cm.addCustomMenuFcn('Simulink:PreContextMenu', @getMcMasterTool);
    cm.addCustomFilterFcn('McMasterTool:RCRclear', @RCRFilter);
    cm.addCustomFilterFcn('McMasterTool:RCRslice', @RCRFilter);
end

function schemaFcns = getMcMasterTool(callbackInfo)
    schemaFcns = {@getRCRContainer};
end

function schema = getRCRContainer(callbackInfo)
    schema = sl_container_schema;
    schema.label = 'Reach/Coreach';
    schema.childrenFcns = {@getRCRReachSel, @getRCRCoreachSel, ...
        @getRCRBothSel, @getRCRClear, @getRCRSlice, @getRCRSetColor};
end

%%  Define Color Option
function schema = getRCRSetColor(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Set Colour';
    schema.userdata = 'RCRsetColor';
    schema.callback = @RCRSetColorCallback;
end

function RCRSetColorCallback(callbackInfo)
    try
        eval(['global ' bdroot(gcs) '_reachCoreachObject;']);
        eval(['x =~isempty(' bdroot(gcs) '_reachCoreachObject);']);
        if x
            eval(['y = isvalid(' bdroot(gcs) '_reachCoreachObject);']);
            if y
                eval(['z = (get_param(bdroot(gcs), ''handle'') == ' bdroot(gcs) '_reachCoreachObject.RootSystemHandle);']);
                if z
                else
                    eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
                end
            else
                eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
            end
        else
            eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
        end
        reachCoreachGUI
        collectGarbageRCR();
    catch ME
        getReport(ME)
        rethrow(ME);
    end
end

%%  Define Reach Option
function schema = getRCRReachSel(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Reach From Selected';
    schema.userdata = 'RCRreachSel';
    schema.callback = @RCRReachCallback;
end

function RCRReachCallback(callbackInfo)
    try
        eval(['global ' bdroot(gcs) '_reachCoreachObject;'])
        eval(['x =~isempty(' bdroot(gcs) '_reachCoreachObject);']);
        if x
            eval(['y = isvalid(' bdroot(gcs) '_reachCoreachObject);']);
            if y
                eval(['z = (get_param(bdroot(gcs), ''handle'') == ' bdroot(gcs) '_reachCoreachObject.RootSystemHandle);']);
                if z
                    eval([bdroot(gcs) '_reachCoreachObject.reachAll(gcbs, gcls);']);
                else
                    eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
                    eval([bdroot(gcs) '_reachCoreachObject.reachAll(gcbs, gcls);']);
                end
            else
                eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
                eval([bdroot(gcs) '_reachCoreachObject.reachAll(gcbs, gcls);']);
            end
        else
            eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
            eval([bdroot(gcs) '_reachCoreachObject.reachAll(gcbs, gcls);']);
        end
        collectGarbageRCR();
        
    catch ME
        getReport(ME)
        rethrow(ME);
    end
end

%%  Define Coreach Option
function schema = getRCRCoreachSel(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Coreach From Selected';
    schema.userdata = 'RCRcoreachSel';
    schema.callback = @RCRCoreachCallback;
end

function RCRCoreachCallback(callbackInfo)
    try
        eval(['global ' bdroot(gcs) '_reachCoreachObject;'])
        eval(['x =~isempty(' bdroot(gcs) '_reachCoreachObject);']);
        if x
            eval(['y = isvalid(' bdroot(gcs) '_reachCoreachObject);']);
            if y
                eval(['z = (get_param(bdroot(gcs), ''handle'') == ' bdroot(gcs) '_reachCoreachObject.RootSystemHandle);']);
                if z
                    eval([bdroot(gcs) '_reachCoreachObject.coreachAll(gcbs, gcls);']);
                else
                    eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
                    eval([bdroot(gcs) '_reachCoreachObject.coreachAll(gcbs, gcls);']);
                end
            else
                eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
                eval([bdroot(gcs) '_reachCoreachObject.coreachAll(gcbs, gcls);']);
            end
        else
            eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
            eval([bdroot(gcs) '_reachCoreachObject.coreachAll(gcbs, gcls);']);
        end
        collectGarbageRCR();
    catch ME
        getReport(ME)
        rethrow(ME);
    end
end

%%  Define Reach/Coreach Option
function schema = getRCRBothSel(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Reach/Coreach From Selected';
    schema.userdata = 'RCRbothSel';
    schema.callback = @RCRBothCallback;
end

function RCRBothCallback(callbackInfo)
    try
        eval(['global ' bdroot(gcs) '_reachCoreachObject;']);
        eval(['x =~isempty(' bdroot(gcs) '_reachCoreachObject);']);
        sel = gcbs;
        lineSel = gcls;
        if x
            eval(['y = isvalid(' bdroot(gcs) '_reachCoreachObject);']);
            if y
                eval(['z = (get_param(bdroot(gcs), ''handle'') == ' bdroot(gcs) '_reachCoreachObject.RootSystemHandle);']);
                if z
                    eval([bdroot(gcs) '_reachCoreachObject.reachAll(sel, lineSel);']);
                    eval([bdroot(gcs) '_reachCoreachObject.coreachAll(sel, lineSel);']);
                else
                    eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
                    eval([bdroot(gcs) '_reachCoreachObject.reachAll(sel, lineSel);']);
                    eval([bdroot(gcs) '_reachCoreachObject.coreachAll(sel, lineSel);']);
                end
            else
                eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
                eval([bdroot(gcs) '_reachCoreachObject.reachAll(sel, lineSel);']);
                eval([bdroot(gcs) '_reachCoreachObject.coreachAll(sel, lineSel);']);
            end
        else
            eval([bdroot(gcs) '_reachCoreachObject = ReachCoreach(bdroot(gcs));']);
            eval([bdroot(gcs) '_reachCoreachObject.reachAll(sel, lineSel);']);
            eval([bdroot(gcs) '_reachCoreachObject.coreachAll(sel, lineSel);']);
        end
        collectGarbageRCR();
    catch ME
        getReport(ME)
        rethrow(ME);
    end
end

%%  Define Clear Option
function schema = getRCRClear(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Clear Reach/Coreach';
    schema.tag = 'McMasterTool:RCRclear';
    schema.userdata = 'RCRclear';
    schema.callback = @RCRclearCallback;
end

function RCRclearCallback(callbackInfo)
    try
        eval(['global ' bdroot(gcs) '_reachCoreachObject;']);
        eval([bdroot(gcs) '_reachCoreachObject.clear();']);
        collectGarbageRCR();
    catch ME
        getReport(ME)
        rethrow(ME);
    end
end

%%  Define Slice Option
function schema = getRCRSlice(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Slice';
    schema.tag = 'McMasterTool:RCRslice';
    schema.userdata = 'RCRslice';
    schema.callback = @RCRsliceCallback;
end

function RCRsliceCallback(callbackInfo)
    try
        eval(['global ' bdroot(gcs) '_reachCoreachObject;']);
        eval([bdroot(gcs) '_reachCoreachObject.slice();']);
        collectGarbageRCR();
    catch ME
        getReport(ME)
        rethrow(ME);
    end
end

% Grey out options for Clear and Slice when there is no ReachCoreach object
function state = RCRFilter(callbackInfo)
    eval(['global ' bdroot(gcs) '_reachCoreachObject;']);
    eval(['v =~isempty(' bdroot(gcs) '_reachCoreachObject);']);
    if v
        eval(['w = isvalid(' bdroot(gcs) '_reachCoreachObject);']);
        if w
            eval(['x = (get_param(bdroot(gcs), ''handle'') == ' bdroot(gcs) '_reachCoreachObject.RootSystemHandle);']);
            if x
                eval(['y =~isempty(' bdroot(gcs) '_reachCoreachObject.ReachedObjects);']);
                eval(['z =~isempty(' bdroot(gcs) '_reachCoreachObject.CoreachedObjects);']);
                if y || z
                    state = 'Enabled';
                else
                    state = 'Disabled';
                end
            else
                state = 'Disabled';
            end
        else
            state = 'Disabled';
        end
    else
        state = 'Disabled';
    end
end

%% Garbage collection for ReachCoreach objects
function collectGarbageRCR()
    globals = who('global');
    sys = cellfun(@(x) x(1:end-19), globals, 'un', 0);
    opensys = find_system('SearchDepth', 0);
    indicesToKeep = ismember(sys, opensys);
    for i = 1:length(globals)
        if (indicesToKeep(i) == 0)
            w = strfind(globals{i}, 'reachCoreachObject');
            if ~isempty(w)
                eval(['global ' globals{i} ';'])
                eval(['x =~isempty(' globals{i} ');']);
                if x
                    eval(['y =~isvalid(' globals{i} ');']);
                    if y
                        eval([globals{i} '.delete;']);
                    end
                end
            end
        end
    end
end
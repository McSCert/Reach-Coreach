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
    schema.childrenFcns = {@getRCRSetColor, @getRCRReachSel, @getRCRCoreachSel, @getRCRBothSel, @getRCRClear, @getRCRSlice};
end

function schema = getRCRSetColor(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Set Color';
    schema.userdata = 'RCRsetColor';
    schema.callback = @RCRSetColorCallback;
end

function RCRSetColorCallback(callbackInfo)
    rcrGUI
end

function schema = getRCRReachSel(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Reach From Selected';
    schema.userdata = 'RCRreachSel';
    schema.callback = @RCRReachCallback;
end

function RCRReachCallback(callbackInfo)
    eval(['global ' bdroot(gcs) '_reachCoreachObject;'])
    eval(['flag=isa(' bdroot(gcs) '_reachCoreachObject, ''ReachCoreach'');'])
    if flag
        eval([bdroot(gcs) '_reachCoreachObject.reachAll(gcbs);']);
    else
        eval([bdroot(gcs) '_reachCoreachObject=ReachCoreach(gcs);'])
        eval([bdroot(gcs) '_reachCoreachObject.reachAll(gcbs);'])
    end
end

function schema = getRCRCoreachSel(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Coreach From Selected';
    schema.userdata = 'RCRcoreachSel';
    schema.callback = @RCRCoreachCallback;
end

function RCRCoreachCallback(callbackInfo)
    eval(['global ' bdroot(gcs) '_reachCoreachObject;'])
    eval(['flag=isa(' bdroot(gcs) '_reachCoreachObject, ''ReachCoreach'');'])
    if flag
        eval([bdroot(gcs) '_reachCoreachObject.coreachAll(gcbs);'])
    else
        eval([bdroot(gcs) '_reachCoreachObject=ReachCoreach(gcs);'])
        eval([bdroot(gcs) '_reachCoreachObject.coreachAll(gcbs);'])
    end
end

function schema = getRCRBothSel(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Reach/Coreach From Selected';
    schema.userdata = 'RCRbothSel';
    schema.callback = @RCRbothCallback;
end

function RCRbothCallback(callbackInfo)
    eval(['global ' bdroot(gcs) '_reachCoreachObject;'])
    eval(['flag=isa(' bdroot(gcs) '_reachCoreachObject, ''ReachCoreach'');'])
    if flag
        eval([bdroot(gcs) '_reachCoreachObject.reachAll(gcbs);'])
        eval([bdroot(gcs) '_reachCoreachObject.coreachAll(gcbs);'])
    else
        eval(['global ' bdroot(gcs) '_reachCoreachObject;'])
        eval([bdroot(gcs) '_reachCoreachObject.reachAll(gcbs);'])
        eval([bdroot(gcs) '_reachCoreachObject.coreachAll(gcbs);'])
    end
end

function schema = getRCRClear(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Clear Highlighting';
    schema.userdata = 'RCRclear';
    schema.callback = @RCRclearCallback;
end

function RCRclearCallback(callbackInfo)
    eval(['global ' bdroot(gcs) '_reachCoreachObject;'])
    eval([bdroot(gcs) '_reachCoreachObject.clear();'])
end

function schema = getRCRSlice(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Slice';
    schema.userdata = 'RCRslice';
    schema.callback = @RCRsliceCallback;
end

function RCRsliceCallback(callbackInfo)
    eval(['global ' bdroot(gcs) '_reachCoreachObject;'])
    eval([bdroot(gcs) '_reachCoreachObject.slice();'])
end

% Grey out menu options for clear and slice when 
% the currently selected block is not a Data Store block
function state = RCRFilter(callbackInfo)
    if (exist([bdroot(gcs) '_reachCoreachObject'], 'var')==1)
            state = 'Enabled';
    else
            state = 'Disabled';
    end
end
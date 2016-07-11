%% Register custom menu function to beginning of Simulink Editor's context menu
function sl_customization(cm)
  cm.addCustomMenuFcn('Simulink:PreContextMenu', @getMcMasterTool);
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
    global reachCoreachObject;
    reachCoreachObject.reachAll(gcbs);
end

function schema = getRCRCoreachSel(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Coreach From Selected';
    schema.userdata = 'RCRcoreachSel';
    schema.callback = @RCRCoreachCallback;
end

function RCRCoreachCallback(callbackInfo)
    global reachCoreachObject;
    reachCoreachObject.coreachAll(gcbs);
end

function schema = getRCRBothSel(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Reach/Coreach From Selected';
    schema.userdata = 'RCRbothSel';
    schema.callback = @RCRbothCallback;
end

function RCRbothCallback(callbackInfo)
    global reachCoreachObject;
    reachCoreachObject.reachAll(gcbs);
    reachCoreachObject.coreachAll(gcbs);
end

function schema = getRCRClear(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Clear Highlighting';
    schema.userdata = 'RCRclear';
    schema.callback = @RCRclearCallback;
end

function RCRclearCallback(callbackInfo)
    global reachCoreachObject;
    reachCoreachObject.clear();
end

function schema = getRCRSlice(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Slice';
    schema.userdata = 'RCRslice';
    schema.callback = @RCRsliceCallback;
end

function RCRsliceCallback(callbackInfo)
    global reachCoreachObject;
    reachCoreachObject.slice();
end
function varargout = reachCoreachGUI(varargin)
% REACHCOREACHGUI MATLAB code for reachCoreachGUI.fig
%      REACHCOREACHGUI, by itself, creates a new REACHCOREACHGUI or raises the existing
%      singleton*.
%
%      H = REACHCOREACHGUI returns the handle to a new REACHCOREACHGUI or the handle to
%      the existing singleton*.
%
%      REACHCOREACHGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in REACHCOREACHGUI.M with the given input arguments.
%
%      REACHCOREACHGUI('Property','Value',...) creates a new REACHCOREACHGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before reachCoreachGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to reachCoreachGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help reachCoreachGUI

% Last Modified by GUIDE v2.5 24-Feb-2017 11:32:42

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @reachCoreachGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @reachCoreachGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before reachCoreachGUI is made visible.
function reachCoreachGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to reachCoreachGUI (see VARARGIN)

% Choose default command line output for reachCoreachGUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% Set the lists to the currently used colours
eval(['global ' bdroot(gcs) '_reachCoreachObject;']);
eval(['[fgcolor, bgcolor] = ' bdroot(gcs) '_reachCoreachObject.getColor();']);

colorList_fg = get(handles.popupmenufore, 'String');
colorList_bg = get(handles.popupmenuback, 'String');

idx_fg = find(strcmp(colorList_fg, fgcolor));
idx_bg = find(strcmp(colorList_bg, bgcolor));

set(handles.popupmenufore, 'Value', idx_fg);
set(handles.popupmenuback, 'Value', idx_bg);


% UIWAIT makes reachCoreachGUI wait for user response (see UIRESUME)
% uiwait(handles.reachCoreachGUI);


% --- Outputs from this function are returned to the command line.
function varargout = reachCoreachGUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in popupmenufore.
function popupmenufore_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenufore (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenufore contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenufore


% --- Executes during object creation, after setting all properties.
function popupmenufore_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenufore (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end


% --- Executes on selection change in popupmenuback.
function popupmenuback_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenuback (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenuback contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenuback


% --- Executes during object creation, after setting all properties.
function popupmenuback_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenuback (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end


% --- Executes on button press in confirmbutton.
function confirmbutton_Callback(hObject, eventdata, handles)
% hObject    handle to confirmbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

eval(['global ' bdroot(gcs) '_reachCoreachObject;']);

% Get colours selected
colorList_fg = get(handles.popupmenufore, 'String');
colorList_bg = get(handles.popupmenuback, 'String');
idx_fg = get(handles.popupmenufore, 'Value');
idx_bg = get(handles.popupmenuback, 'Value');

if ~(idx_fg == 1) && ~(idx_bg == 1)
    % Set colours
    eval([bdroot(gcs) '_reachCoreachObject.setColor(colorList_fg{idx_fg}, colorList_bg{idx_bg});']);
    % Re-highlight
    eval([bdroot(gcs) '_reachCoreachObject.hiliteObjects()']);
    %Close window
    close(handles.reachCoreachGUI)
else
    errordlg('Please select a colour for both the foreground and background.', 'No Colour')
end

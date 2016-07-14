function varargout = rcrGUI(varargin)
% RCRGUI MATLAB code for rcrGUI.fig
%      RCRGUI, by itself, creates a new RCRGUI or raises the existing
%      singleton*.
%
%      H = RCRGUI returns the handle to a new RCRGUI or the handle to
%      the existing singleton*.
%
%      RCRGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RCRGUI.M with the given input arguments.
%
%      RCRGUI('Property','Value',...) creates a new RCRGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before rcrGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to rcrGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help rcrGUI

% Last Modified by GUIDE v2.5 11-Jun-2015 14:56:12

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @rcrGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @rcrGUI_OutputFcn, ...
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


% --- Executes just before rcrGUI is made visible.
function rcrGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to rcrGUI (see VARARGIN)

% Choose default command line output for rcrGUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes rcrGUI wait for user response (see UIRESUME)
% uiwait(handles.rcrgui);


% --- Outputs from this function are returned to the command line.
function varargout = rcrGUI_OutputFcn(hObject, eventdata, handles) 
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
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
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
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in confirmbutton.
function confirmbutton_Callback(hObject, eventdata, handles)
% hObject    handle to confirmbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
eval(['global ' bdroot(gcs) '_reachCoreachObject;']);
colstring=get(handles.popupmenuback, 'String');
colstring2=get(handles.popupmenufore, 'String');
whichstring=get(handles.popupmenuback, 'Value');
whichstring2=get(handles.popupmenufore, 'Value');
if ~(whichstring==1)&&~(whichstring2==1)
    eval([bdroot(gcs) '_reachCoreachObject.setColor(colstring2{whichstring2}, colstring{whichstring});']);
    eval([bdroot(gcs) '_reachCoreachObject.hiliteObjects()']);
    close(handles.rcrgui)
else
    disp('Please select two colours.')
end


% --- Executes during object creation, after setting all properties.
function rcrgui_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rcrgui (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

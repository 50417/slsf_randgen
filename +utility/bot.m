function varargout = bot(varargin)

%BOT  Block diagram Optimization Tool
%
%   BOT
%   optimizes the layout of the current Simulink block diagram.
%   Blocks and lines are resized and moved until their vertices satisfy
%   a 5 pixel grid.
%   You can define safety zones around blocks and line; The program
%   then moves blocks and lines, until their safety zones do not overlap.
%   Think of blocks and lines as magnets repelling each other.
%   Lines can be rerouted and intersecting lines can be untangled.
%   Finally, the program tries to compact the diagram by moving the blocks
%   closer to each other. Think of lines as contracting rubber bands.
%
%   For more information about parameters see also BOTBOT.

%   J. J. Buchholz, Hochschule Bremen, http://buchholz.hs-bremen.de, 2014

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @bot_OpeningFcn, ...
    'gui_OutputFcn',  @bot_OutputFcn, ...
    'gui_LayoutFcn',  [], ...
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


% --- Executes just before bot is made visible.
function bot_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

set (handles.slider_margin_line, ...
    'Tooltipstring', sprintf([ ...
    'Safety margins around lines that other lines and ' ...
    'blocks do not violate.\n' ...
    'Increase this property if lines are too close.' ...
    ]));

set (handles.slider_margin_block, ...
    'Tooltipstring', sprintf([ ...
    'Safety margins around blocks that other blocks and ' ...
    'lines do not violate.\n' ...
    'Increase this property if blocks are too close.' ...
    ]));

set (handles.slider_margin_explode, ...
    'Tooltipstring', sprintf([ ...
    'If you switch on the explode flag, margin_explode ' ...
    'defines a temporarily enlarged block margin.\n' ...
    'Increase this property if blocks have many ports.' ...
    ]));

set (handles.slider_port_factor, ...
    'Tooltipstring', sprintf([ ...
    'The distance between adjacent ports of a block is made ' ...
    'greater than port_factor*margin_line.\n' ...
    'Increase this property if blocks are too small or ' ...
    'if you experience blinkers or spaceships.' ...
    ]));

set (handles.slider_t_pause, ...
    'Tooltipstring', sprintf([ ...
    'Pause between two animation steps.\n' ...
    'Increase this property to slow down the animation.\n' ...
    'You can modify this property during the optimization.' ...
    ]));

set (handles.checkbox_animate, ...
    'Tooltipstring', sprintf([ ...
    'Display every optimization step in the diagram.\n' ...
    'Blocks and lines actually move in real time.\n' ...
    'Switching off this flag can speed up the optimization ' ...                                                                                                                                                 is flag can speed up the optimization
    'a little bit. \n' ...
    'On the other hand you cannot immediately stop it if ' ...
    'something goes wrong.' ...
    ]));

set (handles.checkbox_autozoom, ...
    'Tooltipstring', sprintf([ ...
    'Zoom in or out until all blocks and lines visible.\n' ...
    'Do this in every optimization step.' ...
    ]));

set (handles.checkbox_verbose, ...
    'Tooltipstring', sprintf([ ...
    'Display the current activity in the command window.\n' ...
    'Usually only used for debugging.' ...
    ]));

set (handles.checkbox_single, ...
    'Tooltipstring', sprintf([ ...
    'Minimize blocks with one inport and one outport.\n' ...
    'Use if you prefer compact diagrams.\n' ...
    'The sizes of standard blocks are defined in ' ...
    'function block_defaults. \n' ...
    'You can easily adapt them to your needs.' ...
    ]));

set (handles.checkbox_multi, ...
    'Tooltipstring', sprintf([ ...
    'Minimize blocks with more than one inport or outport.\n' ...
    'Large blocks are minimized according to port_factor. ' ...
    ]));

set (handles.checkbox_explode, ...
    'Tooltipstring', sprintf([ ...
    'Use the enlarged block margin (margin_explode) to make ' ...
    'more room between blocks for multiple lines.\n' ...
    'Usually used with reroute.' ...
    ]));

set (handles.checkbox_reroute, ...
    'Tooltipstring', sprintf([ ...
    'Reroute all lines. \nCan be useful, if lines have many  ' ...
    'vertices. Matlab''s reroute algorithm needs improvement.\n' ...
    'Usually used with explode.' ...
    ]));

set (handles.checkbox_unoverlap, ...
    'Tooltipstring', sprintf([ ...
    'Make sure the safety zones defined by margin_line and ' ...
    'margin_block do not overlap.\n' ...
    'Switching this flag off can lead to unexpected results.\n' ...
    'Be warned. ;-)' ...
    ]));

set (handles.checkbox_untangle, ...
    'Tooltipstring', sprintf([ ...
    'Untangle lines that intersect at least twice.' ...
    ]));

set (handles.checkbox_backwards, ...
    'Tooltipstring', sprintf([ ...
    'Move all line vertices and destination blocks towards ' ...
    'their source blocks.\n' ...
    'This compacts the diagram.\n' ...
    'Blocks connected via a straight line are not moved as a group.\n' ...
    'Block oszillations can be suppressed by switching off ' ...
    'the backwards or the forwards flags.' ...
    ]));

set (handles.checkbox_forwards, ...
    'Tooltipstring', sprintf([ ...
    'Move all line vertices and source blocks towards their ' ...
    'destination blocks.\n' ...
    'For more information see backwards. ' ...
    ]));

set (handles.pushbutton_start, ...
    'Tooltipstring', sprintf([ ...
    'Start the optimization.\n' ...
    'Do not try to modify the block diagram during the optimization.\n' ...
    'The optimization can be interrupted via the Stop button.' ...
    ]));

set (handles.pushbutton_stop, ...
    'Tooltipstring', sprintf([ ...
    'Stop the optimization.\n' ...
    'Wait for the flash signal before restarting the optimization.' ...
    ]));

set (handles.pushbutton_reload, ...
    'Tooltipstring', sprintf([ ...
    'Reload the last saved version of the current block diagram.\n' ...
    'All unsaved optimizations will be lost.' ...
    ]));

set (handles.edit_margin_line, ...
    'String', get (handles.slider_margin_line, 'Value'))

set (handles.edit_margin_block, ...
    'String', get (handles.slider_margin_block, 'Value'))

set (handles.edit_margin_explode, ...
    'String', get (handles.slider_margin_explode, 'Value'))

set (handles.edit_port_factor, ...
    'String', get (handles.slider_port_factor, 'Value'))

set (handles.edit_t_pause, ...
    'String', get (handles.slider_t_pause, 'Value'))

% Choose default command line output for bot
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes bot wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = bot_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in pushbutton_start.
function pushbutton_start_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global communication

if isempty (gcs)
    
    errordlg ('Please open an unlocked Simulink model.')
    
    return
    
end

set (handles.pushbutton_start, 'Enable', 'off')
set (handles.pushbutton_stop, 'Enable', 'on')
set (handles.pushbutton_reload, 'Enable', 'off')

communication.pushbutton_start = handles.pushbutton_start;
communication.pushbutton_stop = handles.pushbutton_stop;
communication.pushbutton_reload = handles.pushbutton_reload;

botbot ( ...
    'margin_line', str2double (get (handles.edit_margin_line, 'string')), ...
    'margin_block', str2double (get (handles.edit_margin_block, 'string')), ...
    'margin_explode', str2double (get (handles.edit_margin_explode, 'string')), ...
    'port_factor', str2double (get (handles.edit_port_factor, 'string')), ...
    't_pause', str2double (get (handles.edit_t_pause, 'string')), ...
    'minimize_single', logical (get (handles.checkbox_single, 'value')), ...
    'minimize_multi', logical (get (handles.checkbox_multi, 'value')), ...
    'animate', logical (get (handles.checkbox_animate, 'value')), ...
    'autozoom', logical (get (handles.checkbox_autozoom, 'value')), ...
    'verbose', logical (get (handles.checkbox_verbose, 'value')), ...
    'explode', logical (get (handles.checkbox_explode, 'value')), ...
    'reroute', logical (get (handles.checkbox_reroute, 'value')), ...
    'unoverlap', logical (get (handles.checkbox_unoverlap, 'value')), ...
    'untangle', logical (get (handles.checkbox_untangle, 'value')), ...
    'backwards', logical (get (handles.checkbox_backwards, 'value')), ...
    'forwards', logical (get (handles.checkbox_forwards, 'value')))


% --- Executes on button press in pushbutton_reload.
function pushbutton_reload_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_reload (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

current_system = gcs;

slash_index = strfind (current_system, '/');

if isempty (slash_index)
    
    close_system (current_system, 0);
    
    open_system (current_system);
    
else
    
    model = current_system (1 : slash_index - 1);
    
    close_system (model, 0);
    
    open_system (model);
    open_system (current_system);
    
end


% --- Executes on button press in checkbox_animate.
function checkbox_animate_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_animate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_animate


% --- Executes on button press in pushbutton_test.
function pushbutton_test_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_test (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on slider movement.
function slider_t_pause_Callback(hObject, eventdata, handles)
% hObject    handle to slider_t_pause (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global parameters

parameters.t_pause = get (handles.slider_t_pause, 'Value');

set (handles.edit_t_pause, ...
    'String', parameters.t_pause)


% --- Executes during object creation, after setting all properties.
function slider_t_pause_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_t_pause (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function edit_t_pause_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_t_pause (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function slider_margin_block_Callback(hObject, eventdata, handles)
% hObject    handle to slider_margin_block (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

set (handles.edit_margin_block, ...
    'String', get (handles.slider_margin_block, 'Value'))


% --- Executes during object creation, after setting all properties.
function slider_margin_block_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_margin_block (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function edit_margin_block_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_margin_block (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function slider_margin_line_Callback(hObject, eventdata, handles)
% hObject    handle to slider_margin_line (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

set (handles.edit_margin_line, ...
    'String', get (handles.slider_margin_line, 'Value'))


% --- Executes during object creation, after setting all properties.
function slider_margin_line_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_margin_line (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function edit_margin_line_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_margin_line (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function slider_margin_explode_Callback(hObject, eventdata, handles)
% hObject    handle to slider_margin_explode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

set (handles.edit_margin_explode, ...
    'String', get (handles.slider_margin_explode, 'Value'))


% --- Executes during object creation, after setting all properties.
function slider_margin_explode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_margin_explode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function edit_margin_explode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_margin_explode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_stop.
function pushbutton_stop_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global communication

communication.external_stop = true;

set (handles.pushbutton_start, 'Enable', 'on')
set (handles.pushbutton_reload, 'Enable', 'on')

% --- Executes on button press in checkbox_explode.
function checkbox_explode_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_explode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_explode


% --- Executes on button press in checkbox_untangle.
function checkbox_untangle_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_untangle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_untangle


% --- Executes on button press in checkbox_converge.
function checkbox_converge_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_converge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_converge


% --- Executes on button press in checkbox_reroute.
function checkbox_reroute_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_reroute (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_reroute


% --- Executes on button press in checkbox_unoverlap.
function checkbox_unoverlap_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_unoverlap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_unoverlap


% --- Executes on button press in checkbox_verbose.
function checkbox_verbose_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_verbose (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_verbose


% --- Executes on button press in checkbox_autozoom.
function checkbox_autozoom_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_autozoom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_autozoom


% --- Executes on slider movement.
function slider_port_factor_Callback(hObject, eventdata, handles)
% hObject    handle to slider_port_factor (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

set (handles.edit_port_factor, ...
    'String', floor (get (handles.slider_port_factor, 'Value')))



% --- Executes during object creation, after setting all properties.
function slider_port_factor_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_port_factor (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function edit_port_factor_Callback(hObject, eventdata, handles)
% hObject    handle to edit_port_factor (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_port_factor as text
%        str2double(get(hObject,'String')) returns contents of edit_port_factor as a double


% --- Executes during object creation, after setting all properties.
function edit_port_factor_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_port_factor (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_single.
function checkbox_single_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_single (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_single


% --- Executes on button press in checkbox_backwards.
function checkbox_backwards_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_backwards (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_backwards


% --- Executes on button press in checkbox_forwards.
function checkbox_forwards_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_forwards (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_forwards


% --- Executes on button press in checkbox_multi.
function checkbox_multi_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_multi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_multi

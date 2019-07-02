function botbot (varargin)

%BOTBOT  Block diagram Optimization Tool worker
%
%   BOTBOT
%   optimizes the layout of the current Simulink block diagram.
%   Blocks and lines are resized and moved until their vertices satisfy
%   a 5 pixel grid. 
%   You can define safety zones around blocks and line; The program 
%   then moves blocks and lines, until their safety zones do not overlap. 
%   Think of blocks and lines as magnets repelling each other.
%   Lines can be rerouted and intersecting lines can be untangled.
%   Finally, the program tries to compact the diagram by moving the blocks
%   closer to each other. Think of lines as contracting rubber bands.
%   If called without parameters, default values for all properties are
%   used.
%
%   BOTBOT ('property_name1', property_value1, ...)
%   overrides the default property values:
% 
%   margin_line:     Safety margins around lines that other lines and 
%                    blocks do not violate. 
%                    Increase this property if lines are too close.
%                    (default: 5)
%
%   margin_block:    Safety margins around blocks that other blocks and 
%                    lines do not violate. 
%                    Increase this property if blocks are too close.
%                    (default: 10)
%
%   margin_explode:  If you switch on the explode flag, margin_explode 
%                    defines a temporarily enlarged block margin. 
%                    Increase this property if blocks have many ports.
%                    (default: 50) 
%
%   port_factor:     The distance between adjacent ports of a block is made  
%                    greater than port_factor*margin_line.
%                    Increase this property if blocks are too small or
%                    if you experience blinkers or spaceships. 
%                    (default: 4) 
%
%   t_pause:         Pause between two animation steps.
%                    Increase this property to slow down the animation.
%                    You can modify this property during the optimization.
%                    (default: 0)
%
%   animate:         Display every optimization step in the diagram.
%                    Blocks and lines actually move in real time.
%                    Switching off this flag can speed up the optimization                                                                                                                                                  is flag can speed up the optimization 
%                    a little bit.
%                    On the other hand you cannot immediately stop it if 
%                    something goes wrong.
%                    (default: true)
%
%   autozoom:        Zoom in or out until all blocks and lines visible.
%                    Do this in every optimization step.
%                    (default: true)
%
%   verbose:         Display the current activity in the command window.
%                    Usually only used for debugging.
%                    (default: false)
%
%   minimize_single: Minimize blocks with one inport and one outport.
%                    Use if you prefer compact diagrams.
%                    The sizes of standard blocks are defined in 
%                    function block_defaults. 
%                    You can easily adapt them to your needs.
%                    (default: true)
%
%   minimize_multi:  Minimize blocks with more than one inport or outport.
%                    Large blocks are minimized according to port_factor.
%                    (default: false)
%
%   explode:         Use the enlarged block margin (margin_explode) to make
%                    more room between blocks for multiple lines.
%                    Usually used with reroute. 
%                    (default: false)
%                    
%   reroute:         Reroute all lines. Can be useful, if lines have many 
%                    vertices. 
%                    Matlab's reroute algorithm needs improvement.  
%                    Usually used with explode.
%                    (default: false)
%
%   unoverlap:       Make sure the safety zones defined by margin_line and
%                    margin_block do not overlap. 
%                    Switching this flag off can lead to unexpected results. 
%                    Be warned. ;-) 
%                    (default: true)
%
%   untangle:        Untangle lines that intersect at least twice.
%                    (default: true)
%
%   backwards:       Move all line vertices and destination blocks towards 
%                    their source blocks. 
%                    This compacts the diagram. 
%                    Blocks connected via a straight line are not moved as
%                    a group.
%                    Block oszillations can be suppressed by switching off 
%                    the backwards or the forwards flags.   
%                    (default: true)
%
%   forwards:        Move all line vertices and source blocks towards their
%                    destination blocks. 
%                    For more information see backwards.   
%                    (default: true)
%
%   See also BOT.

%   J. J. Buchholz, Hochschule Bremen, http://buchholz.hs-bremen.de, 2014

global communication
global parameters
global flags
global block
global line
global phantoms
global keep_going

clear block
clear line
clear phantoms

tic

%%
initialize

gridisize_lines

gridisize_blocks

debranch

%%
if flags.explode
    
    explode
    
end

%%
if flags.reroute
    
    reroute
    
end

%%
if flags.unoverlap
    
    unoverlap
    
end

%%
if flags.untangle
    
    untangle
    
end

%%
if flags.backwards
    
    converge_backwards
    
end

%%
if flags.forwards
    
    converge_forwards
    
end

finalize

%%
    function initialize
        
        input_parser = inputParser;
        
        addParamValue (input_parser, 'margin_line', 5, @isnumeric)
        addParamValue (input_parser, 'margin_block', 10, @isnumeric)
        addParamValue (input_parser, 'margin_explode', 50, @isnumeric)
        addParamValue (input_parser, 'port_factor', 4, @isnumeric)
        addParamValue (input_parser, 't_pause', 0, @isnumeric)
        addParamValue (input_parser, 'animate', true, @islogical)
        addParamValue (input_parser, 'autozoom', true, @islogical)
        addParamValue (input_parser, 'verbose', false, @islogical)
        addParamValue (input_parser, 'minimize_single', true, @islogical)
        addParamValue (input_parser, 'minimize_multi', false, @islogical)
        addParamValue (input_parser, 'explode', false, @islogical)
        addParamValue (input_parser, 'reroute', false, @islogical)
        addParamValue (input_parser, 'unoverlap', true, @islogical)
        addParamValue (input_parser, 'untangle', true, @islogical)
        addParamValue (input_parser, 'backwards', true, @islogical)
        addParamValue (input_parser, 'forwards', true, @islogical)
        
        parse (input_parser, varargin{:})
        
        parameters.bot_grid = 5;
        parameters.port_factor = max (2, ceil (input_parser.Results.port_factor));
        parameters.margin_line = parameters.bot_grid*ceil (input_parser.Results.margin_line/parameters.bot_grid);
        parameters.margin_block = max (10, parameters.bot_grid*ceil (input_parser.Results.margin_block/parameters.bot_grid));
        parameters.margin_explode = max (25, parameters.bot_grid*ceil (input_parser.Results.margin_explode/parameters.bot_grid));
        parameters.t_pause = input_parser.Results.t_pause;
        flags.animate = input_parser.Results.animate;
        flags.autozoom = input_parser.Results.autozoom;
        flags.verbose = input_parser.Results.verbose;
        flags.minimize_single = input_parser.Results.minimize_single;
        flags.minimize_multi = input_parser.Results.minimize_multi;
        flags.explode = input_parser.Results.explode;
        flags.reroute = input_parser.Results.reroute;
        flags.unoverlap = input_parser.Results.unoverlap;
        flags.untangle = input_parser.Results.untangle;
        flags.backwards = input_parser.Results.backwards;
        flags.forwards = input_parser.Results.forwards;
        
        if flags.verbose
            
            clc
            
        end

        communication.external_stop = false;
        
        if ...
                isempty (gcs) || ...
                isempty (get_param(gcs, 'Parent')) && ...
                strcmp (get_param (gcs, 'Lock'), 'on')
            
            errordlg ('Please open an unlocked Simulink model.')

            reset_buttons
            
            error ('Please open an unlocked Simulink model.')
            
        end
        
        block.names = find_system (gcs, 'searchdepth', 1, 'type', 'block');
        block.names(strcmp (gcs, block.names)) = [];
        block.n = length (block.names);
        
        if block.n < 2
            
            errordlg ('The block diagram should have at least two blocks.')
            
            reset_buttons
            
            error ('The block diagram should have at least two blocks.')
            
        end
        
        block.handles = cell2mat (get_param (block.names, 'Handle'));
        block.types = get (block.handles, 'BlockType');
        block.orientations = get_param (block.handles, 'Orientation');

        port_handles = cell2mat (get_param (block.handles, 'PortHandles'));
        
        block.inport_handles = {port_handles.Inport}';
        block.outport_handles = {port_handles.Outport}';
        
        initialize_lines
        
        annotation_handles = find_system (gcs, 'FindAll', 'on', 'type', 'annotation');
        
        set (annotation_handles, 'selected', 'off')
        set (block.handles, 'selected', 'off')
        set (line.handles, 'selected', 'off')
        
    end

%%
    function initialize_lines
        
        delete_unconnected_lines
        
        line.handles = find_system (gcs, 'findall', 'on', 'searchdepth', 1, 'type', 'line');
        
        line.n = length (line.handles);
        
        line.segment_acc = cell (line.n, 1);
        
    end

%%
    function delete_unconnected_lines
        
        delete_line (find_system (gcs, 'findall', 'on', 'searchdepth', 1, 'type', 'line', 'Connected', 'off'));
        
    end

%% 
    function gridisize_lines

        for i_line = 1 : line.n

            points = get (line.handles(i_line), 'points');
            
            points = parameters.bot_grid*round (points/parameters.bot_grid);

            set (line.handles(i_line), 'points', points)
            
        end
        
    end

%%
    function gridisize_blocks
        
        block_defaults = define_block_defaults;
        
        for i_block = 1 : block.n
            
            block.positions(i_block, :) = get_param (block.handles(i_block), 'position');
            
            width = block.positions(i_block, 3) - block.positions(i_block, 1);
            height = block.positions(i_block, 4) - block.positions(i_block, 2);
            
            block.positions(i_block, 1 : 2) = ...
                parameters.bot_grid*round (block.positions(i_block, 1 : 2)/parameters.bot_grid);
            
            width = parameters.bot_grid*ceil (width/parameters.bot_grid);
            height = parameters.bot_grid*ceil (height/parameters.bot_grid);
            
            max_port = max ( ...
                length (block.inport_handles{i_block}), ...
                length (block.outport_handles{i_block}));
          
            if max_port > 1
                
                if flags.minimize_multi
                    
                    if flags.verbose
                        
                        disp minimize_multi
                        
                    end
                    
                    switch block.orientations{i_block}
                        
                        case {'right', 'left'}
                            
                            height = parameters.port_factor*(max_port - 1)*parameters.margin_line;
                            
                        case {'up', 'down'}
                            
                            width = parameters.port_factor*(max_port - 1)*parameters.margin_line;
                            
                    end
                    
                end
                
            else
                
                if flags.minimize_single
                    
                    if flags.verbose
                        
                        disp minimize_single
                        
                    end
                    
                    if any (strcmp (block_defaults.height_10, block.types(i_block)))
                        
                        block_default_height = 10;
                        
                    elseif any (strcmp (block_defaults.height_20, block.types(i_block)))
                        
                        block_default_height = 20;
                        
                    elseif any (strcmp (block_defaults.height_40, block.types(i_block)))
                        
                        block_default_height = 40;
                        
                    else
                        
                        block_default_height = 30;
                        
                    end
                    
                    switch block.orientations{i_block}
                        
                        case {'right', 'left'}
                            
                            height = block_default_height;
                            
                        case {'up', 'down'}
                            
                            width = block_default_height;
                            
                    end
                    
                end
                
            end
            
            while true
                
                if ...
                        strcmp (block.types(i_block), 'Sum') && ...
                        strcmp (get (block.handles(i_block), 'IconShape'), 'round')
                    
                    width = height;
                    
                    
                end
                
                block.positions(i_block, 3) = block.positions(i_block, 1) + width;
                block.positions(i_block, 4) = block.positions(i_block, 2) + height;
                
                set (block.handles(i_block), 'position', block.positions(i_block, :));
                
                inport_positions = get (block.inport_handles{i_block}, 'position');
                outport_positions = get (block.outport_handles{i_block}, 'position');
                
                if length (block.inport_handles{i_block}) > 1
                    
                    inport_positions = cell2mat (inport_positions);
                    
                end
                
                if length (block.outport_handles{i_block}) > 1
                    
                    outport_positions = cell2mat (outport_positions);
                    
                end
                
                block.positions(i_block, :) = get (block.handles(i_block), 'position');
                
                port_positions = [inport_positions; outport_positions];
                
                delta_port_positions = [diff(inport_positions, 1, 1); diff(outport_positions, 1, 1)];
                
                switch block.orientations{i_block}
                    
                    case {'right', 'left'}
                        
                        if ...
                                any (mod (block.positions(i_block, :), parameters.bot_grid)) || ...
                                ~isempty (port_positions) && ...
                                any (mod (port_positions(:,2), parameters.bot_grid)) || ...
                                ~isempty (delta_port_positions) && ...
                                any (delta_port_positions(:,2) < parameters.port_factor*parameters.margin_line)
                            
                            height = height + parameters.bot_grid;
                            
                        else
                            
                            break
                            
                        end
                        
                    case {'up', 'down'}
                        
                        if ...
                                any (mod (block.positions(i_block, :), parameters.bot_grid)) || ...
                                ~isempty (port_positions) && ...
                                any (mod (port_positions(:,1), parameters.bot_grid)) || ...
                                ~isempty (delta_port_positions) && ...
                                any (delta_port_positions(:,1) < parameters.port_factor*parameters.margin_line)
                            
                            width = width + parameters.bot_grid;
                            
                        else
                            
                            break
                            
                        end
                        
                end
                
            end
           
         end
       
        block.margins = block.positions;
        block.margins(:, 1 : 2) = block.margins(:, 1 : 2) - parameters.margin_block;
        block.margins(:, 3 : 4) = block.margins(:, 3 : 4) + parameters.margin_block;
        
        kill_diagonals
        
        clean_up_lines
        
    end

%% 
    function kill_diagonals
        
        for i_line = 1 : line.n
            
            points = get (line.handles(i_line), 'points');
            
            n_points = size (points, 1);
            
            i_point = 1;
            
            while i_point < n_points - 1
                
                if ...
                        points (i_point, 1) ~= points (i_point + 1, 1) && ...
                        points (i_point, 2) ~= points (i_point + 1, 2)
                    
                    points = [ ...
                        points(1 : i_point, :); ...
                        [points(i_point, 1), points(i_point + 1, 2)]; ...
                        points(i_point + 1 : end, :)];
                    
                    n_points = n_points + 1;
                    
                else
                    
                    i_point = i_point + 1;
                    
                end
                
            end
            
            set (line.handles(i_line), 'points', points);
            
        end
        
    end

%%
    function debranch
        
        lines_to_be_deleted = [];
        
        phantoms = [];
        
        for i_line = 1 : line.n
            
            line_current = line.handles(i_line);
            
            if  isempty (get (line_current, 'DstBlock'))
                
                lines_to_be_deleted = [lines_to_be_deleted; line_current];
                
            elseif isempty (get (line_current, 'SrcBlock'))
                
                phantom.destination_block_handle = get (line_current, 'DstBlockHandle');
                phantom.destination_block_name = get (phantom.destination_block_handle, 'Name');
                
                phantom.destination_port_handle = get (line_current, 'DstPortHandle');
                phantom.destination_port_number = get (phantom.destination_port_handle, 'PortNumber');
                
                points_new = [];
                
                line_parent = line_current;
                
                while line_parent ~= -1
                    
                    line_current = line_parent;
                    
                    lines_to_be_deleted = [lines_to_be_deleted; line_current];
                    
                    points_current = get (line_current, 'Points');
                    
                    points_new = [points_current; points_new];
                    
                    line_parent = get (line_current, 'LineParent');
                    
                end
                
                phantom.source_block_handle = get (line_current, 'SrcBlockHandle');
                phantom.source_port_handle = get (line_current, 'SrcPortHandle');
                phantom.source_port_number = get (phantom.source_port_handle, 'PortNumber');
                
                phantom.handle = add_block ( ...
                    'built-in/Subsystem', ...
                    [gcs, '/', get(phantom.source_block_handle, 'Name')], ...
                    'MakeNameUnique', 'on', ...
                    'Position', get (phantom.source_block_handle, 'Position'), ...
                    'Orientation', get (phantom.source_block_handle, 'Orientation'), ...
                    'ShowName', 'off' ...
                    );
                
                set (phantom.handle, 'ZOrder', get (phantom.source_block_handle, 'ZOrder') - 1)
                
                n_outports_current = length (block.outport_handles{block.handles==phantom.source_block_handle});
                
                n_inports_current = length (block.inport_handles{block.handles==phantom.source_block_handle});
                
                for i_outport = 1 : n_outports_current
                    
                    add_block ( ...
                        'built-in/Outport', ...
                        [gcs, '/', get(phantom.handle, 'Name'), '/Out', num2str(i_outport)] ...
                        )
                    
                end
                
                for i_inport = 1 : n_inports_current
                    
                    add_block ( ...
                        'built-in/Inport', ...
                        [gcs, '/', get(phantom.handle, 'Name'), '/In', num2str(i_inport)] ...
                        )
                    
                end
                
                phantom.points = points_new;
                
                phantom.name = get(phantom.handle, 'Name');
                
                phantoms = [phantoms; phantom];
                
            end
            
            align_phantoms
            
        end
        
        delete_line (lines_to_be_deleted)
        
        for i_phantom = 1 : length (phantoms)
            
            phantoms(i_phantom).line_handle = add_line (gcs, ...
                [phantoms(i_phantom).name, '/', num2str(phantoms(i_phantom).source_port_number)], ...
                [phantoms(i_phantom).destination_block_name, '/',  num2str(phantoms(i_phantom).destination_port_number)]);
            
            set (phantoms(i_phantom).line_handle, 'Points', phantoms(i_phantom).points)
            
        end
        
        initialize_lines
        
        clean_up_lines
        
        find_line_block_indices
        
    end

%%
    function align_phantoms
        
        for i_phantom = 1 : length (phantoms)
            
            phantom = phantoms (i_phantom);
            
            set (phantom.handle, 'Position', get (phantom.source_block_handle, 'Position'))
            
        end
        
    end

%%
    function find_line_block_indices
        
        line.source_block_indices = zeros (line.n, 1);
        line.destination_block_indices = zeros (line.n, 1);
        block.out_line_indices = cell (block.n, 1);
        block.in_line_indices = cell (block.n, 1);
        
        for i_line = 1 : line.n
            
            source_block_handle = get (line.handles(i_line), 'SrcBlockHandle');
            destination_block_handle = get (line.handles(i_line), 'DstBlockHandle');
            
            for i_phantom = 1 : length (phantoms)
                
                if phantoms(i_phantom).handle == source_block_handle
                    
                    source_block_handle = phantoms(i_phantom).source_block_handle;
                    
                end
                
            end
            
            for i_block = 1 : block.n
                
                if block.handles(i_block) == source_block_handle
                    
                    line.source_block_indices(i_line) = i_block;
                    block.out_line_indices{i_block} = [block.out_line_indices{i_block}, i_line];
                    
                end
                
                if block.handles(i_block) == destination_block_handle
                    
                    line.destination_block_indices(i_line) = i_block;
                    block.in_line_indices{i_block} = [block.in_line_indices{i_block}, i_line];
                    
                end
                
            end
            
        end
        
    end

%%
    function explode
        
        block.margins = block.positions;
        block.margins(:, 1 : 2) = block.margins(:, 1 : 2) - parameters.margin_explode;
        block.margins(:, 3 : 4) = block.margins(:, 3 : 4) + parameters.margin_explode;
        
        keep_going.explode = true;
        
        while keep_going.explode && ~communication.external_stop
            
            if flags.verbose
                
                disp explode
                
            end
            
            keep_going.explode = false;
            
            block.acc = zeros (block.n, 2);
            
            unoverlap_blocks_blocks
            
            move_blocks
            
            draw_pause
            
        end
        
        block.margins = block.positions;
        block.margins(:, 1 : 2) = block.margins(:, 1 : 2) - parameters.margin_block;
        block.margins(:, 3 : 4) = block.margins(:, 3 : 4) + parameters.margin_block;
        
    end

%%
    function reroute
        
        if flags.verbose
            
            disp reroute
            
        end
        
        src_port_handle = zeros (line.n, 1);
        dst_port_handle = zeros (line.n, 1);
        dist = zeros (line.n, 1);
        
        for i = 1 : line.n
            
            src_port_handle(i) = get (line.handles(i), 'srcporthandle');
            dst_port_handle(i) = get (line.handles(i), 'dstporthandle');
            
            src_port_handle_position = get (src_port_handle(i), 'position');
            dst_port_handle_position = get (dst_port_handle(i), 'position');
            
            dist(i) = sum (abs (src_port_handle_position - dst_port_handle_position));
            
        end
        
        [~, sort_i] = sort (dist);
        
        delete (line.handles)
        
        for i = 1 : line.n
            
            if communication.external_stop
                return
            end
            
            ii = sort_i(i);
            
            current_line = add_line (gcs, src_port_handle(ii), dst_port_handle(ii), 'autorouting', 'on');
            
            for i_phantom = 1 : length(phantoms)
                
                if phantoms(i_phantom).destination_port_handle == dst_port_handle(ii)
                    
                    phantoms(i_phantom).line_handle = current_line;
                    
                end
                
            end
            
            draw_pause
            
        end
        
        line.handles = find_system (gcs, 'findall', 'on', 'searchdepth', 1, 'type', 'line');
        line.n = length (line.handles);
 
        gridisize_lines
        
        clean_up_lines
        
        find_line_block_indices
        
    end

%%
    function clean_up_lines
        
        for i_line = 1 : line.n
            
            clean_up_line (i_line)
            
        end
        
    end

%%
    function clean_up_line (i_line)
        
        points = get (line.handles(i_line), 'points');
        
        points = [ ...
            points(1, :); ...
            points(1, :); ...
            points; ...
            points(end, :); ...
            points(end, :)];
        
        n_points = size (points, 1);
        
        i_point = 3;
        
        while i_point < n_points - 3
            
            if ...
                    points (i_point, 1) == points (i_point + 1, 1) && ...
                    points (i_point + 1, 1) == points (i_point + 2, 1) || ...
                    points (i_point, 2) == points (i_point + 1, 2) && ...
                    points (i_point + 1, 2) == points (i_point + 2, 2)
                
                points (i_point + 1, :) = [];
                
                n_points = n_points - 1;
                
            else
                
                i_point = i_point + 1;
                
            end
            
        end
        
        set (line.handles(i_line), 'points', points)
        
    end

%%
    function initialize_segment_accumulators
        
        for i_line = 1 : line.n
            
            initialize_segment_accumulator (i_line)
            
        end
        
    end

%%
    function initialize_segment_accumulator (i_line)
        
        points = get (line.handles(i_line), 'points');
        
        n_points = size (points, 1);
        
        line.segment_acc{i_line} = zeros (n_points, 2);
        
    end

%%
    function initialize_block_accumulators
        
        block.acc = zeros (block.n, 2);
        
    end

%%
    function unoverlap
        
        if flags.verbose
            
            disp unoverlap
            
        end
        
        keep_going.unoverlap = true;
        
        while keep_going.unoverlap && ~communication.external_stop
            
            keep_going.unoverlap = false;
            
            initialize_block_accumulators
            initialize_segment_accumulators
            
            unoverlap_blocks_lines
            unoverlap_lines_lines
            unoverlap_blocks_blocks

            move_lines
            move_blocks
            draw_pause
            
        end
        
    end

%%
    function unoverlap_blocks_blocks
        
        for i_block = 1 : block.n - 1
            
            for  j_block = i_block + 1 : block.n
                
                delta = [...
                    block.margins(i_block, 3) - block.margins(j_block, 1), ...
                    block.margins(j_block, 3) - block.margins(i_block, 1), ...
                    block.margins(i_block, 4) - block.margins(j_block, 2), ...
                    block.margins(j_block, 4) - block.margins(i_block, 2)];
                
                [delta_min, delta_min_ind] = min (delta);
                
                if delta_min > 0
                    
                    switch delta_min_ind
                        
                        case 1
                            
                            block.acc(j_block, 1) = block.acc(j_block, 1) + 1;
                            block.acc(i_block, 1) = block.acc(i_block, 1) - 1;
                            
                        case 2
                            
                            block.acc(i_block, 1) = block.acc(i_block, 1) + 1;
                            block.acc(j_block, 1) = block.acc(j_block, 1) - 1;
                            
                        case 3
                            
                            block.acc(j_block, 2) = block.acc(j_block, 2) + 1;
                            block.acc(i_block, 2) = block.acc(i_block, 2) - 1;
                            
                        case 4
                            
                            block.acc(i_block, 2) = block.acc(i_block, 2) + 1;
                            block.acc(j_block, 2) = block.acc(j_block, 2) - 1;
                            
                    end
                    
                end
                
            end
            
        end
        
    end

%%
    function unoverlap_blocks_lines
        
        for i_block = 1 : block.n
            
            for i_line = 1 : line.n
                
                points = get (line.handles(i_line), 'points');
                
                n_points = size (points, 1);
                
                for i_segment = 3 : n_points - 3
                    
                    segment_margin = sort (points(i_segment : i_segment + 1, :))';
                    
                    segment_margin(1 : 2) = segment_margin(1 : 2) - parameters.margin_line;
                    segment_margin(3 : 4) = segment_margin(3 : 4) + parameters.margin_line;
                    
                    delta = [...
                        segment_margin(3) - block.margins(i_block, 1), ...
                        block.margins(i_block, 3) - segment_margin(1), ...
                        segment_margin(4) -  block.margins(i_block, 2), ...
                        block.margins(i_block, 4) - segment_margin(2)];
                    
                    [delta_min, delta_min_ind] = min (delta);
                    
                    if delta_min > 0
                        
                        if ...
                                points(i_segment, 1) == points(i_segment + 1, 1) && ...
                                points(i_segment, 2) ~= points(i_segment + 1, 2)
                            
                            switch delta_min_ind
                                
                                case 1
                                    
                                    block.acc(i_block, 1) = ...
                                        block.acc(i_block, 1) + 1;
                                    
                                    line.segment_acc{i_line}(i_segment, 1) = ...
                                        line.segment_acc{i_line}(i_segment, 1) - 1;
                                    
                                case 2
                                    
                                    block.acc(i_block, 1) = ...
                                        block.acc(i_block, 1) - 1;
                                    
                                    line.segment_acc{i_line}(i_segment, 1) = ...
                                        line.segment_acc{i_line}(i_segment, 1) + 1;
                                    
                            end
                            
                        else
                            
                            switch delta_min_ind
                                
                                case 3
                                    
                                    block.acc(i_block, 2) = ...
                                        block.acc(i_block, 2) + 1;
                                    
                                    line.segment_acc{i_line}(i_segment, 2) = ...
                                        line.segment_acc{i_line}(i_segment, 2) - 1;
                                    
                                case 4
                                    
                                    block.acc(i_block, 2) = ...
                                        block.acc(i_block, 2) - 1;
                                    
                                    line.segment_acc{i_line}(i_segment, 2) = ...
                                        line.segment_acc{i_line}(i_segment, 2) + 1;
                                    
                            end
                            
                        end
                        
                    end
                    
                end
                
            end
            
        end
        
    end

%%
    function unoverlap_lines_lines
        
        for i_line = 1 : line.n - 1
            
            points_i = get (line.handles(i_line), 'points');
            
            n_points_i = size (points_i, 1);
            
            for j_line = i_line + 1 : line.n
                
                points_j = get (line.handles(j_line), 'points');
                
                n_points_j = size (points_j, 1);
                
                if all (points_i(1,:) == points_j(1,:))
                    
                    continue
                    
                end
                
                for i_segment = 3 : n_points_i - 3
                    
                    for j_segment = 3 : n_points_j - 3
                        
                        if ...
                                points_i(i_segment, 1) == points_i(i_segment + 1, 1) && ...
                                points_i(i_segment, 2) ~= points_i(i_segment + 1, 2) && ...
                                points_j(j_segment, 1) == points_j(j_segment + 1, 1) && ...
                                points_j(j_segment, 2) ~= points_j(j_segment + 1, 2)
                            
                            margin_i = sort (points_i(i_segment : i_segment + 1, :))';
                            
                            margin_i(1 : 2) = margin_i(1 : 2) - parameters.margin_line;
                            margin_i(3 : 4) = margin_i(3 : 4) + parameters.margin_line;
                            
                            margin_j = sort (points_j(j_segment : j_segment + 1, :))';
                            
                            margin_j(1 : 2) = margin_j(1 : 2) - parameters.margin_line;
                            margin_j(3 : 4) = margin_j(3 : 4) + parameters.margin_line;
                            
                            delta = [...
                                margin_i(3) - margin_j(1), ...
                                margin_j(3) - margin_i(1), ...
                                margin_i(4) - margin_j(2), ...
                                margin_j(4) - margin_i(2)];
                            
                            if all (delta > 0)
                                
                                if  points_i(i_segment, 1) < points_j(j_segment, 1)
                                    
                                    line.segment_acc{j_line}(j_segment, 1) = ...
                                        line.segment_acc{j_line}(j_segment, 1) + 1;
                                    
                                    line.segment_acc{i_line}(i_segment, 1) = ...
                                        line.segment_acc{i_line}(i_segment, 1) - 1;
                                    
                                elseif points_i(i_segment, 1) > points_j(j_segment, 1)
                                    
                                    line.segment_acc{j_line}(j_segment, 1) = ...
                                        line.segment_acc{j_line}(j_segment, 1) - 1;
                                    
                                    line.segment_acc{i_line}(i_segment, 1) = ...
                                        line.segment_acc{i_line}(i_segment, 1) + 1;
                                    
                                else
                                    
                                    endpoints = [...
                                        points_i(i_segment, 2), ...
                                        points_i(i_segment + 1, 2), ...
                                        points_j(j_segment, 2), ...
                                        points_j(j_segment + 1, 2), ...
                                        ];
                                    
                                    [~, index]  = sort (endpoints);
                                    
                                    if ...
                                            (index(2) == 1 || index(3) == 1) && ...
                                            (points_i(i_segment - 1, 1) < points_i(i_segment, 1) || ...
                                            points_i(i_segment + 1, 1) < points_i(i_segment, 1)) || ...
                                            (index(2) == 2 || index(3) == 2) && ...
                                            (points_i(i_segment, 1) < points_i(i_segment + 1, 1) || ...
                                            points_i(i_segment + 2, 1) < points_i(i_segment + 1, 1))
                                        
                                        line.segment_acc{i_line}(i_segment, 1) = ...
                                            line.segment_acc{i_line}(i_segment, 1) - 1;
                                        
                                        line.segment_acc{j_line}(j_segment, 1) = ...
                                            line.segment_acc{j_line}(j_segment, 1) + 1;
                                        
                                    else
                                        
                                        line.segment_acc{i_line}(i_segment, 1) = ...
                                            line.segment_acc{i_line}(i_segment, 1) + 1;
                                        
                                        line.segment_acc{j_line}(j_segment, 1) = ...
                                            line.segment_acc{j_line}(j_segment, 1) - 1;
                                        
                                    end
                                    
                                end
                                
                            end
                            
                        elseif ...
                                points_i(i_segment, 1) ~= points_i(i_segment + 1, 1) && ...
                                points_i(i_segment, 2) == points_i(i_segment + 1, 2) && ...
                                points_j(j_segment, 1) ~= points_j(j_segment + 1, 1) && ...
                                points_j(j_segment, 2) == points_j(j_segment + 1, 2)
                            
                            margin_i = sort (points_i(i_segment : i_segment + 1, :))';
                            
                            margin_i(1 : 2) = margin_i(1 : 2) - parameters.margin_line;
                            margin_i(3 : 4) = margin_i(3 : 4) + parameters.margin_line;
                            
                            margin_j = sort (points_j(j_segment : j_segment + 1, :))';
                            
                            margin_j(1 : 2) = margin_j(1 : 2) - parameters.margin_line;
                            margin_j(3 : 4) = margin_j(3 : 4) + parameters.margin_line;
                            
                            delta = [...
                                margin_i(3) - margin_j(1), ...
                                margin_j(3) - margin_i(1), ...
                                margin_i(4) - margin_j(2), ...
                                margin_j(4) - margin_i(2)];
                            
                            if all (delta > 0)
                                
                                if  points_i(i_segment, 2) < points_j(j_segment, 2)
                                    
                                    line.segment_acc{j_line}(j_segment, 2) = ...
                                        line.segment_acc{j_line}(j_segment, 2) + 1;
                                    
                                    line.segment_acc{i_line}(i_segment, 2) = ...
                                        line.segment_acc{i_line}(i_segment, 2) - 1;
                                    
                                elseif points_i(i_segment, 2) > points_j(j_segment, 2)
                                    
                                    line.segment_acc{j_line}(j_segment, 2) = ...
                                        line.segment_acc{j_line}(j_segment, 2) - 1;
                                    
                                    line.segment_acc{i_line}(i_segment, 2) = ...
                                        line.segment_acc{i_line}(i_segment, 2) + 1;
                                    
                                else
                                    
                                    endpoints = [...
                                        points_i(i_segment, 1), ...
                                        points_i(i_segment + 1, 1), ...
                                        points_j(j_segment, 1), ...
                                        points_j(j_segment + 1, 1), ...
                                        ];
                                    
                                    [~, index]  = sort (endpoints);
                                    
                                    if ...
                                            (index(2) == 1 || index(3) == 1) && ...
                                            (points_i(i_segment - 1, 2) < points_i(i_segment, 2) || ... 
                                            points_i(i_segment + 1, 2) < points_i(i_segment, 2)) || ... 
                                            (index(2) == 2 || index(3) == 2) && ... 
                                            (points_i(i_segment, 2) < points_i(i_segment + 1, 2) || ... 
                                            points_i(i_segment + 2, 2) < points_i(i_segment + 1, 2)) 
                                        
                                        line.segment_acc{i_line}(i_segment, 2) = ...
                                            line.segment_acc{i_line}(i_segment, 2) - 1;
                                        
                                        line.segment_acc{j_line}(j_segment, 2) = ...
                                            line.segment_acc{j_line}(j_segment, 2) + 1;
                                        
                                    else
                                        
                                        line.segment_acc{i_line}(i_segment, 2) = ...
                                            line.segment_acc{i_line}(i_segment, 2) + 1;
                                        
                                        line.segment_acc{j_line}(j_segment, 2) = ...
                                            line.segment_acc{j_line}(j_segment, 2) - 1;
                                        
                                    end
                                    
                                end
                                
                            end
                            
                        end
                        
                    end
                    
                end
                
            end
            
        end
        
    end

%%
    function move_lines
        
        for i_line = 1 : line.n
            
            move_line (i_line)
            
        end
        
    end

%%
    function move_line (i_line)
        
        points = get (line.handles(i_line), 'points');
        
        n_points = size (points, 1);
        
        for i_segment = 3 : n_points - 3
            
            delta_segment = parameters.bot_grid*sign (line.segment_acc{i_line}(i_segment, :));
            
            if any (delta_segment)
                
                keep_going.unoverlap = true;
                
                points(i_segment : i_segment + 1, :) = ...
                    points(i_segment : i_segment + 1, :) + [delta_segment; delta_segment];
                
            end
            
        end
        
        set (line.handles(i_line), 'points', points)
        
        clean_up_line (i_line)
        
    end

%%
    function move_blocks
        
        for i_block = 1 : block.n
            
            move_block (i_block)
            
        end
        
        align_phantoms
        
    end

%%
    function move_block (i_block)
        
        [block_acc_max, block_acc_max_ind] = max (abs (block.acc(i_block, :)));
        
        if block_acc_max > 0
            
            keep_going.unoverlap = true;
            keep_going.explode = true;
            
            [block_positions_save, ...
                block_margins_save, ...
                line_points_save] = save_state;
            
            if block_acc_max_ind == 1
                
                delta_position = parameters.bot_grid*sign ...
                    ([block.acc(i_block, 1), 0]);
                
                for i_line = block.out_line_indices{i_block}
                    
                    if ...
                            line_points_save{i_line}(3,1) == ...
                            line_points_save{i_line}(4,1)
                        
                        line_points_save{i_line}(1 : 4, :) = ...
                            line_points_save{i_line}(1 : 4, :) + ...
                            repmat (delta_position, 4, 1);
                        
                    else
                        
                        line_points_save{i_line}(1 : 3, :) = ...
                            line_points_save{i_line}(1 : 3, :) + ...
                            repmat (delta_position, 3, 1);
                        
                    end
                    
                end
                
                for i_line = block.in_line_indices{i_block}
                    
                    if ...
                            line_points_save{i_line}(end - 2, 1) == ...
                            line_points_save{i_line}(end - 3, 1)
                        
                        line_points_save{i_line}(end - 3 : end, :) = ...
                            line_points_save{i_line}(end - 3 : end, :) + ...
                            repmat (delta_position, 4, 1);
                        
                    else
                        
                        line_points_save{i_line}(end - 2 : end, :) = ...
                            line_points_save{i_line}(end - 2 : end, :) + ...
                            repmat (delta_position, 3, 1);
                        
                    end
                    
                end
                
            else
                
                delta_position = parameters.bot_grid*sign ...
                    ([0, block.acc(i_block, 2)]);
                
                for i_line = block.out_line_indices{i_block}
                    
                    if ...
                            line_points_save{i_line}(3,2) == ...
                            line_points_save{i_line}(4,2)
                        
                        line_points_save{i_line}(1 : 4, :) = ...
                            line_points_save{i_line}(1 : 4, :) + ...
                            repmat (delta_position, 4, 1);
                        
                    else
                        
                        line_points_save{i_line}(1 : 3, :) = ...
                            line_points_save{i_line}(1 : 3, :) + ...
                            repmat (delta_position, 3, 1);
                        
                    end
                    
                end
                
                for i_line = block.in_line_indices{i_block}
                    
                    if ...
                            line_points_save{i_line}(end - 2, 2) == ...
                            line_points_save{i_line}(end - 3, 2)
                        
                        line_points_save{i_line}(end - 3 : end, :) = ...
                            line_points_save{i_line}(end - 3 : end, :) + ...
                            repmat (delta_position, 4, 1);
                        
                    else
                        
                        line_points_save{i_line}(end - 2 : end, :) = ...
                            line_points_save{i_line}(end - 2 : end, :) + ...
                            repmat (delta_position, 3, 1);
                        
                    end
                    
                end
                
            end
            
            block_positions_save(i_block, :) = ...
                block_positions_save(i_block, :) + ...
                [delta_position, delta_position];
            
            block_margins_save(i_block, :) = ...
                block_margins_save(i_block, :) + ...
                [delta_position, delta_position];

            restore_state (...
                block_positions_save, ...
                block_margins_save, ...
                line_points_save)
            
            clean_up_lines

        end
        
    end

%%
    function draw_pause
        
        if flags.animate
            
            drawnow
            
            if flags.autozoom
                
                set_param (gcs, 'ZoomFactor', 'FitSystem')
                
            end
            
            pause (parameters.t_pause)
            
        end
        
    end

%%
    function untangle
        
        keep_going.untangle = true;
        
        while keep_going.untangle && ~communication.external_stop
            
            if flags.verbose
                
                disp untangle
                
            end
            
            keep_going.untangle = false;
            
            untangle_worker
            
        end
        
        function untangle_worker
            
            clean_up_lines
            
            for i_line = 1 : line.n - 1
                
                points_i = get (line.handles(i_line), 'points');
                
                n_points_i = size (points_i, 1);
                
                for j_line = i_line + 1 : line.n
                    
                    if flags.animate
                        
                        set (line.handles, 'selected', 'off')
                        set (line.handles(i_line), 'selected', 'on')
                        set (line.handles(j_line), 'selected', 'on')
                        
                    end
                    
                    points_j = get (line.handles(j_line), 'points');
                    
                    n_points_j = size (points_j, 1);
                    
                    if all (points_i(1,:) == points_j(1,:))
                        
                        continue
                        
                    end
                    
                    first = true;
                    
                    for i_segment = 3 : n_points_i - 3
                        
                        for j_segment = 3 : n_points_j - 3
                            
                             intersection = ...
                                line_intersection ( ...
                                points_i(i_segment : i_segment + 1, :), ...
                                points_j(j_segment : j_segment + 1, :));
                            
                            if ~isempty (intersection)
                                
                                if first
                                    
                                    first_i = i_segment;
                                    first_j = j_segment;
                                    first_intersection = intersection;
                                    
                                    first = false;
                                    
                                else
                                    
                                    second_i = i_segment;
                                    second_j = j_segment;
                                    second_intersection = intersection;
                                    
                                    if first_i == second_i
                                        
                                        points_j_new = [...
                                            points_j(1 : first_j, :); ...
                                            first_intersection; ...
                                            second_intersection; ...
                                            points_j(second_j + 1 : end, :)];
                                        
                                        if ...
                                                norm (points_i(first_i, :) - first_intersection, 1) < ...
                                                norm (points_i(first_i, :) - second_intersection, 1)
                                            
                                            points_i_new = [...
                                                points_i(1 : first_i, :); ...
                                                first_intersection; ...
                                                points_j(first_j + 1 : second_j, :); ...
                                                second_intersection; ...
                                                points_i(second_i + 1 : end, :)];
                                            
                                        else
                                            
                                            points_i_new = [...
                                                points_i(1 : second_i, :); ...
                                                second_intersection; ...
                                                flipud(points_j(first_j + 1 : second_j, :)); ...
                                                first_intersection; ...
                                                points_i(first_i + 1 : end, :)];
                                            
                                        end
                                        
                                    elseif first_j == second_j
                                        
                                        points_i_new = [...
                                            points_i(1 : first_i, :); ...
                                            first_intersection; ...
                                            second_intersection; ...
                                            points_i(second_i + 1 : end, :)];
                                        
                                        if ...
                                                norm (points_j(first_j, :) - first_intersection, 1) < ...
                                                norm (points_j(first_j, :) - second_intersection, 1)
                                            
                                            points_j_new = [...
                                                points_j(1 : first_j, :); ...
                                                first_intersection; ...
                                                points_i(first_i + 1 : second_i, :); ...
                                                second_intersection; ...
                                                points_j(second_j + 1 : end, :)];
                                            
                                        else
                                            
                                            points_j_new = [...
                                                points_j(1 : second_j, :); ...
                                                second_intersection; ...
                                                flipud(points_i(first_i + 1 : second_i, :)); ...
                                                first_intersection; ...
                                                points_j(first_j + 1 : end, :)];
                                        end
                                        
                                        
                                    else
                                        
                                        if first_j < second_j
                                            
                                            points_i_new = [...
                                                points_i(1 : first_i, :); ...
                                                first_intersection; ...
                                                points_j(first_j + 1 : second_j, :); ...
                                                second_intersection; ...
                                                points_i(second_i + 1 : end, :)];
                                            
                                            points_j_new = [...
                                                points_j(1 : first_j, :); ...
                                                first_intersection; ...
                                                points_i(first_i + 1 : second_i, :); ...
                                                second_intersection; ...
                                                points_j(second_j + 1 : end, :)];
                                            
                                        else
                                            
                                            points_i_new = [...
                                                points_i(1 : first_i, :); ...
                                                first_intersection; ...
                                                flipud(points_j(second_j + 1 : first_j, :)); ...
                                                second_intersection; ...
                                                points_i(second_i + 1 : end, :)];
                                            
                                            points_j_new = [...
                                                points_j(1 : second_j, :); ...
                                                second_intersection; ...
                                                flipud(points_i(first_i + 1 : second_i, :)); ...
                                                first_intersection; ...
                                                points_j(first_j + 1 : end, :)];
                                            
                                        end
                                        
                                    end
                                    
                                    set (line.handles(j_line), 'points', points_j_new)
                                    set (line.handles(i_line), 'points', points_i_new)
                                    
                                    unoverlap
                                    
                                    keep_going.untangle = true;
                                    
                                    return
                                    
                                end
                                
                            end
                            
                        end
                        
                    end
                    
                end
                
            end
            
            function intersection = line_intersection (segment_1, segment_2)
                
                intersection = [];
                
                x1 = segment_1(1, 1);
                x2 = segment_2(1, 1);
                x3 = segment_1(2, 1);
                x4 = segment_2(2, 1);
                y1 = segment_1(1, 2);
                y2 = segment_2(1, 2);
                y3 = segment_1(2, 2);
                y4 = segment_2(2, 2);
                
                cx_vec(1) = x1;
                cy_vec(1) = y2;
                cx_vec(2) = x2;
                cy_vec(2) = y1;
                
                for i = 1 : 2
                    
                    cx = cx_vec(i);
                    cy = cy_vec(i);
                    
                    if ...
                            cy == y1 && ...
                            cy == y3 && ...
                            cx == x2 && ...
                            cx == x4 && (...
                            x1 <= cx && ...
                            cx <= x3 || ...
                            x3 <= cx && ...
                            cx <= x1) && (...
                            y2 <= cy && ...
                            cy <= y4 || ...
                            y4 <= cy && ...
                            cy <= y2) || ...
                            cx == x1 && ...
                            cx == x3 && ...
                            cy == y2 && ...
                            cy == y4 && (...
                            y1 <= cy && ...
                            cy <= y3 || ...
                            y3 <= cy && ...
                            cy <= y1) && (...
                            x2 <= cx && ...
                            cx <= x4 || ...
                            x4 <= cx && ...
                            cx <= x2)
                        
                        intersection = [cx, cy];
                        
                    end
                    
                end
                
            end
            
        end
        
    end

%%
    function converge_backwards
        
        keep_going.backwards = true;
        
        while keep_going.backwards && ~communication.external_stop
            
            if flags.verbose
                
                disp converge_backward
                
            end
            
            keep_going.backwards = false;
            
            for i_line = 1 : line.n
                
                if flags.animate
                    
                    set (line.handles, 'selected', 'off')
                    
                    set (line.handles(i_line), 'selected', 'on')
                    
                    drawnow
 
               end
                
                points = get (line.handles(i_line), 'points');
                n_points = size (points, 1);
                
                i_segment = 3;
                
                while (i_segment <= n_points - 3) && ~communication.external_stop
                    
                    delta = points(i_segment + 1, :) - points(i_segment, :);
                    
                    [block_positions_save, ...
                        block_margins_save, ...
                        line_points_save] = save_state;

                    initialize_block_accumulators
                    initialize_segment_accumulators
                    
                    if ...
                            i_segment == n_points - 3 || ...
                            i_segment == n_points - 4
                        
                        i_block = line.destination_block_indices(i_line);
                        
                        block.acc(i_block, :) = -delta;
                        
                        move_block (i_block)
                        
                        align_phantoms
                         
                    else
                        
                        line.segment_acc{i_line}(i_segment + 1, :) = -delta;
                        move_line (i_line)
                        
                    end
                    
                    initialize_segment_accumulator (i_line)
                    initialize_block_accumulators
                    
                    unoverlap_blocks_lines
                    unoverlap_lines_lines
                    unoverlap_blocks_blocks
                    
                    if ...
                            any (any (block.acc)) || ...
                            any (any (cell2mat (line.segment_acc)))
                        
                        restore_state (...
                            block_positions_save, ...
                            block_margins_save, ...
                            line_points_save)
                        
                        i_segment = i_segment + 1;
                        
                    else
                        
                        draw_pause
                        
                        keep_going.backwards = true;
                        
                    end
                    
                    points = get (line.handles(i_line), 'points');
                    n_points = size (points, 1);
                    
                end
                
            end
            
        end
        
    end

%%
    function converge_forwards
        
        keep_going.forwards = true;
        
        while keep_going.forwards
            
            if flags.verbose
                
                disp converge_forward
                
            end
            
            keep_going.forwards = false;
            
            for i_line = 1 : line.n
                
                if flags.animate
                    
                    set (line.handles, 'selected', 'off')
                    
                    set (line.handles(i_line), 'selected', 'on')
                    
                    drawnow                   
 
                end
                
                points = get (line.handles(i_line), 'points');
                n_points = size (points, 1);
                
                i_segment = 3;
                
                while (i_segment <= n_points - 3) && ~communication.external_stop
                    
                    delta = points(i_segment + 1, :) - points(i_segment, :);
                    
                    [block_positions_save, ...
                        block_margins_save, ...
                        line_points_save] = save_state;

                    initialize_block_accumulators
                    initialize_segment_accumulators
                    
                    if ...
                            i_segment == 3 || ...
                            i_segment == 4
                        
                        i_block = line.source_block_indices(i_line);
                        
                        block.acc(i_block, :) = delta;
                        
                        move_block (i_block)
                        
                        align_phantoms
                         
                    else
                        
                        line.segment_acc{i_line}(i_segment - 1, :) = delta;
                        move_line (i_line)
                        
                    end
                    
                    initialize_segment_accumulator (i_line)
                    initialize_block_accumulators
                    
                    unoverlap_blocks_lines
                    unoverlap_lines_lines
                    unoverlap_blocks_blocks
                    
                    if ...
                            any (any (block.acc)) || ...
                            any (any (cell2mat (line.segment_acc)))
                        
                        restore_state (...
                            block_positions_save, ...
                            block_margins_save, ...
                            line_points_save)
                        
                        i_segment = i_segment + 1;
                        
                    else
                        
                        draw_pause
                        
                        keep_going.forwards = true;
                        
                    end
                    
                    points = get (line.handles(i_line), 'points');
                    n_points = size (points, 1);
                    
                end
                
            end
            
        end
        
    end

%%
    function [...
            block_positions_save, ...
            block_margins_save, ...
            line_points_save] = save_state
        
        block_positions_save = block.positions;
        block_margins_save = block.margins;
        
        line_points_save = [];
        
        for i_line = 1 : line.n
            
            line_points_save{i_line} = get (line.handles(i_line), 'points');
            
        end
        
    end

%%
    function restore_state (...
            block_positions_save, ...
            block_margins_save, ...
            line_points_save)
        
        block.positions = block_positions_save;
        block.margins = block_margins_save;
        
        for i_block = 1 : block.n
            
            set (block.handles(i_block), 'position', block.positions(i_block, :));
            
        end
        
        align_phantoms
        
        for i_line = 1 : line.n
            
            set (line.handles(i_line), 'points', line_points_save{i_line});
            
        end
        
    end

%%
    function finalize
        
        set (block.handles, 'selected', 'off')
        set (line.handles, 'selected', 'off')
        
        rebranch
        
        if flags.verbose
            
            toc
            
        end
        
        reset_buttons

        [dat, freq] = audioread ('done.wav');
        sound (dat, freq)

        flash

    end

%%
    function reset_buttons
        
        if isfield (communication, 'pushbutton_start')
            
            set (communication.pushbutton_start, 'Enable', 'on')
            set (communication.pushbutton_stop, 'Enable', 'off')
            set (communication.pushbutton_reload, 'Enable', 'on')
        end
        
    end

%%
    function rebranch
        
        clean_up_lines
        
        mini_segments = [];
        
        for i_phantom = 1 : length (phantoms)
            
            phantom = phantoms(i_phantom);
            
            points = get (phantom.line_handle, 'Points');
            
            n_points = size (points, 1);
            
            for i_point = 3 : n_points - 3
                
                x1 = points(i_point, 1);
                y1 = points(i_point, 2);
                x2 = points(i_point + 1, 1);
                y2 = points(i_point + 1, 2);
                
                if x1 == x2
                    
                    if y1 < y2
                        
                        mini_points = (y1 : parameters.bot_grid : y2)';
                        
                    else
                        
                        mini_points = (y1 : -parameters.bot_grid : y2)';
                        
                    end
                    
                    n_mini_points = length (mini_points);
                    
                    new_mini_segments = [ ...
                        x1*ones(n_mini_points - 1, 1), ...
                        mini_points(1 : end - 1), ...
                        x1*ones(n_mini_points - 1, 1), ...
                        mini_points(2 : end)];

                else
                    
                    if x1 < x2
                        
                        mini_points = (x1 : parameters.bot_grid : x2)';
                        
                    else
                        
                        mini_points = (x1 : -parameters.bot_grid : x2)';
                        
                    end
                    
                    n_mini_points = length (mini_points);
                    
                    new_mini_segments = [ ...
                        mini_points(1 : end - 1), ...
                        y1*ones(n_mini_points - 1, 1), ...
                        mini_points(2 : end), ...
                        y1*ones(n_mini_points - 1, 1)];
                    
                end

                if i_point == n_points - 3

                    new_mini_segments(end, :) = [];
                    
                end
                
                mini_segments = [mini_segments; new_mini_segments];
                
            end
            
            delete_line (phantom.line_handle)
            
            delete (phantom.handle)
            
        end
        
        mini_segments = unique (mini_segments, 'rows', 'stable');
        
        n_mini_segments = size (mini_segments, 1);
        
        for i_mini_segment = 1 : n_mini_segments
            
            add_line (gcs, [ ...
                mini_segments(i_mini_segment, 1 : 2); ...
                mini_segments(i_mini_segment, 3 : 4)])
            
        end
        
        delete_unconnected_lines
        
    end

%%
    function flash
        
        block_color = get (block.handles, 'BackgroundColor');
        
        set (block.handles, 'BackgroundColor', 'green')
        
        pause (0.5)
        
        for i_block = 1 : block.n
            
            set (block.handles(i_block), 'BackgroundColor', block_color{i_block})
            
        end
    end

%%
    function block_defaults = define_block_defaults
        
        block_defaults.height_10 = { ...
            'Inport'; ...
            'Outport'; ...
            'Ground'; ...
            'Terminator' ...
        };
        
        block_defaults.height_20 = { ...
            'Constant'; ...
            'EnablePort'; ...
            'TriggerPort'; ...
            'From'; ...
            'Goto'; ...
            'Clock'; ...
            'FromFile'; ...
            'ToFile'; ...
            'FromWorkspace'; ...
            'ToWorkspace'; ...
            'DataStoreRead'; ...
            'DataStoreWrite'; ...
            'Display'; ...
            'Scope' ...
        };

        block_defaults.height_40 = { ...
            'TransferFcn'; ...
            'ZeroPole'; ...
            'StateSpace'; ...
            'PermuteDimensions'...
        };

    end

end
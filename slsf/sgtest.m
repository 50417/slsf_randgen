% This is entry point to the Random Generator.
% Run this script from the command line. You can edit following options
% (options are always written using all upper-case letters).

NUM_TESTS = 1;                          % Number of models to generate
STOP_IF_ERROR = true;                   % Stop when meet the first simulation error
STOP_IF_OTHER_ERROR = true;             % For errors not related to simulation e.g. unhandled simulation exceptions or code bug
CLOSE_MODEL = false;                    % Close models after simulation
SIMULATE_MODELS = true;                 % Will simulate model if value is true
NUM_BLOCKS = 30;                        % Number of blocks in each model (flat hierarchy)

LOG_SIGNALS = true;                     % If set to true, will log all output signals for later comparison
SIMULATION_MODE = 'accelerator';        % See 'SimulationMode' parameter in http://bit.ly/1WjA4uE
COMPARE_SIM_RESULTS = true;             % Compare simulation results.

%%%%%%%%%%%%%%%%%%%% End of Options %%%%%%%%%%%%%%%%%%%%

% For each run of this script, new random numbers will be selected. If you
% want to stop this behavior (e.g. if you want to generate the SAME models
% each time you run this script) set the value of rand_start_over variable
% in workspace. Do not edit below.

if ~ exist('rng_state', 'var')
    rng_state = [];
end

if ~exist('rand_start_over', 'var')
    rand_start_over = false;
end

if isempty(rng_state) || rand_start_over
    disp('~~ RandomNumbers: Starting Over ~~');
    rng(0,'twister');           % Random Number Generator Init
else
    disp('~~ RandomNumbers: Storing from previous state ~~');
    rng(rng_state);
end

load_system('Simulink');

num_suc_sim = 0;
num_err_sim = 0;

errors = {};
e_map = struct;

for ind = 1:NUM_TESTS
    model_name = strcat('sampleModel', int2str(ind));
    
    % Store random number settings
    rng_state = rng;
    
    sg = simple_generator(NUM_BLOCKS, model_name, SIMULATE_MODELS, CLOSE_MODEL, LOG_SIGNALS, SIMULATION_MODE, COMPARE_SIM_RESULTS);
    
    try
        if ~sg.go()

            num_err_sim = num_err_sim + 1;

            % Keep record of the exception

            c = struct;
            c.m_no = model_name;
            e = sg.last_exc;

            if(strcmp(e.identifier, 'MATLAB:MException:MultipleErrors'))
                e = e.cause{1};
            end

            e_map = util.map_inc(e_map, e.identifier);

            if STOP_IF_ERROR
                disp('BREAKING FROM MAIN LOOP AS ERROR OCCURRED IN SIMULATION');
                break;
            end

    %         if ~strcmp(e.identifier, 'Simulink:DataType:PropForwardDataTypeError')
    %             break;
    %         end

        else
            num_suc_sim = num_suc_sim + 1;
%             sg.close();           % Close Model

        end
    catch e
        % Exception occurred when simulating, but the error was not caught.
        % Reason: new types of simulation errors
        disp('EEEEEEEEEEEEEEEEEEEE Unhandled Error In Simulation EEEEEEEEEEEEEEEEEEEEEEEEEE');
        e
        e.message
        e.cause
        e.stack.line
        
        if STOP_IF_OTHER_ERROR
            disp('Stopping: STOP_IF_OTHER_ERROR=True.');
            break;
        else
            e_map = util.map_inc(e_map, e.identifier);
        end
    end
    
    disp(['%%% %%%% %%%% %%%% %%%% AFTER ' int2str(ind) 'th SIMULATION %%% %%%% %%%% %%%% %%%%']);
    num_suc_sim
    num_err_sim
    e_map
    
end

disp('----------- SGTEST END -------------');

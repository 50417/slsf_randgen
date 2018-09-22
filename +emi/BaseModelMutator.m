classdef (Abstract) BaseModelMutator < handle
    %BASEMODELMUTATOR Mutates a single model to create k mutants
    %   Individual mutants are created by calling instances of
    %   BaseMutantGenerator implementations
    
    properties
        result;
    end
    
    properties(Access=protected)
        exp_data;
        REPORT_DIR_FOR_THIS_MODEL;
        
        exp_no = []; % loop counter value of MAIN_LOOP
        model_data = []; % input
        
        sys;
        m_id;
        
        num_mutants;
        
        l = logging.getLogger('emi.BaseModelMutator');
        
        block_data; % Data for each block
        dead; 
        live;
        compiled_types;
    end
    
    methods
        
        function obj = BaseModelMutator(exp_data, exp_no, model_data)
            % Constructor
            obj.exp_data = exp_data;
            obj.exp_no = exp_no;
            obj.model_data = model_data;
        end    
        
        function go(obj)
            
            assert(~isempty(obj.model_data));
            assert(~isempty(obj.exp_no));
            
            obj.save_random_number_generator_state();
            
            obj.init();
            
            if ~ obj.open_model()
                return;
            end
            
            ret = false;
            
            original_backup_created = false;
            original_backup = [obj.sys '_original'];
            
            if ~ isempty(emi.cfg.DEBUG_SUBSYSTEM)
                obj.l.info('Keeping original model open');
                save_system(obj.sys, [tempdir filesep original_backup]);
                open_system(original_backup);
                original_backup_created = true;
            end
            
            
            try
                ret = obj.process_single_model();
            catch e
                obj.add_exception_in_result(e);
                obj.l.error(getReport(e, 'extended'));
            end
            
            if ~ ret && emi.cfg.KEEP_ERROR_MUTANT_PARENT_OPEN
               obj.open_model(true); 
            else
                obj.close_model();
            end
            
            if original_backup_created
                bdclose(original_backup);
                delete([tempdir filesep original_backup '.slx']);
            end
        end
        
    end
    
    methods(Access = protected)
        
        function save_random_number_generator_state(~)
            rng_state = rng; %#ok<NASGU>
            save(emi.cfg.WS_FILE_NAME, emi.cfg.RNG_VARNAME_IN_WS, '-append');
        end
        
        
        function init(obj)
            obj.model_data = table2struct(obj.model_data);
            obj.sys = obj.model_data.sys;
            obj.m_id = obj.model_data.m_id;
            
            obj.choose_num_mutants();
            
            obj.result = emi.ReportForModel(obj.exp_no, obj.m_id);
            
            % Create Directories
            obj.REPORT_DIR_FOR_THIS_MODEL = [obj.exp_data.REPORTS_BASE filesep int2str(obj.exp_no)];
            mkdir(obj.REPORT_DIR_FOR_THIS_MODEL);
        end
        
        function choose_num_mutants(obj)
            obj.num_mutants = emi.cfg.MUTANTS_PER_MODEL;
            obj.result.mutants = cell(obj.num_mutants, 1);
        end
        
        function add_exception_in_result(obj, e)
            obj.l.error(['Exception: ' e.identifier]);
            obj.result.exception = true;
            obj.result.exception_ob = e;
            obj.result.exception_id = e.identifier;
        end
        
        function opens = open_model(obj, varargin)
            % varargin{1}: boolean: whether to use open_system by force.
            
            if nargin > 1
                use_open_system = varargin{1};
            else
                use_open_system = false;
            end
            
            opens = true;
            addpath(obj.model_data.loc_input);
            try
                if use_open_system
                    open_system(obj.sys);
                else
                    emi.open_or_load_model(obj.sys);
                end
            catch e
                opens = false;
                obj.l.error('Model did not open');
                obj.add_exception_in_result(e);
            end
            
            obj.result.opens = opens;
            rmpath(obj.model_data.loc_input);
        end
        
        function ret = process_single_model(obj)
            obj.get_dead_and_live_blocks();
            
            obj.enable_signal_logging();
            
            ret = obj.create_mutants();
        end
        
        function ret = create_mutants(obj)
            ret = true;
            
            for i=1:obj.num_mutants
                obj.open_model();
                a_mutant = emi.SimpleMutantGenerator(i, obj.sys,...
                    obj.exp_data, obj.REPORT_DIR_FOR_THIS_MODEL);
                
                a_mutant.blocks = obj.block_data;
                a_mutant.live_blocks = obj.live;
                a_mutant.dead_blocks = obj.dead;
                a_mutant.compiled_types = obj.compiled_types;
                
                a_mutant.go()
                obj.result.mutants{i} = a_mutant.result;
                
                obj.save_my_result();
                
                if ~ a_mutant.result.is_ok
                    obj.l.error('Breaking from mutant gen loop due to error');
                    ret = false;
                    break;
                end
            end
        end
        
        function get_dead_and_live_blocks(obj)
            
            function x = get_nonempty(x)
                x = x(rowfun(@(~,p,~) ~isempty(p{1}) , x(:,:),...
                'OutputFormat', 'uniform'), :);
            end
            
            function x = remove_model_names(x)
                % remove model name from the blocks
                x(:, 'fullname') = cellfun(@(p) utility.strip_first_split(...
                    p, '/', '/') ,x{:, 'fullname'}, 'UniformOutput', false);
            end
            
            blocks = struct2table(obj.model_data.blocks);
            blocks = get_nonempty(blocks);
            blocks = remove_model_names(blocks);
            
            obj.block_data = blocks;
            
            deads = cellfun(@(p) p ==0 ,blocks{:,'percentcov'});
            
            obj.dead = blocks(deads, :);
            obj.live = blocks(~deads, :);
            
            % compiled types
            % TODO to improve performance can merge with previous blocks
            % struct
            ctypes = struct2table(obj.model_data.datatypes);
            ctypes = get_nonempty(ctypes);
            ctypes = remove_model_names(ctypes);
            
            obj.compiled_types = ctypes;
            
            % compiled data types
        end
        
        function save_my_result(obj)
            modelreport = obj.result.get_report();  %#ok<NASGU>
            save([obj.REPORT_DIR_FOR_THIS_MODEL filesep...
                emi.cfg.REPORT_FOR_A_MODEL_FILENAME], emi.cfg.REPORT_FOR_A_MODEL_VARNAME);
        end
        
        function enable_signal_logging(~)
            
        end
        
        function close_model(obj)
            emi.pause_interactive();
            bdclose(obj.sys);
        end
    end
    
end


classdef BaseMainLoop < handle
    %BASEMAINLOOP The "main loop" of an EMI experiment
    %   Detailed explanation goes here
    
    properties
        model_list = emi.cfg.INPUT_MODEL_LIST;
        
        models; 
        
        data_var_name = 'covexp_result';
        
        l = logging.getLogger('emi.BaseMainLoop');
        
        exp_start_time;
        
        exp_data;
    end
    
    methods
        
        function load_models_list(obj)
            read_data = load(obj.model_list);
            models_data = read_data.(obj.data_var_name);
            obj.models = struct2table(models_data.models);
        end
        
        
        function apply_model_list_filters(obj)
            % No exception, num_zero_cov > 0
            obj.models = obj.models(rowfun(@(p, q)~p && ~isempty(q) &&...
                q{1}>0, obj.models(:, {'exception', 'numzerocov'}),...
                'OutputFormat', 'uniform'), :);
        end
        
        function init(obj)
            % Init exp start time and create directories 
            obj.exp_start_time = datestr(now, covcfg.DATETIME_DATE_TO_STR);
            
            obj.exp_data = struct();
            
            obj.exp_data.REPORTS_BASE = [emi.cfg.REPORTS_DIR filesep obj.exp_start_time];
            mkdir(obj.exp_data.REPORTS_BASE);
            copyfile(['+emi' filesep 'cfg.m'], obj.exp_data.REPORTS_BASE);
        end
        
        function go(obj)
            obj.l.info('--- Starting Main Loop! ---')
            
            emi.cfg.validate_configurations();
            
            obj.init();
            
            obj.load_models_list();
            obj.apply_model_list_filters();
            
            obj.choose_models();
            obj.process_all_models();
            
            obj.l.info('--- Returning from Main Loop! ---')
        end
        
        function choose_models(obj)
            obj.models = obj.models(...
                randi([1, size(obj.models, 1)], 1, emi.cfg.NUM_MAINLOOP_ITER), :);
        end
        
        function process_all_models(obj)
            models_cpy = obj.models;
            
            if emi.cfg.PARFOR
                error('TODO')
            else
                for i=1:size(models_cpy, 1)
                    obj.l.info(sprintf('Processing %d of %d models', i, size(models_cpy, 1)));
                    emi.mutate_single_model(i, models_cpy(1, :), obj.exp_data);
                end
            end
        end
    end
    
end


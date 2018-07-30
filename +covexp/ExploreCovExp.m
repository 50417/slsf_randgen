classdef ExploreCovExp < covexp.CorpusCovExp
    %EXPLORECOVEXP Explore a directory and includes all models found in it
    %for experiments, including subdirectories.
    %   TODO NOT TESTED YET!!
    
    properties
        EXPLORE_SUBDIRS = true;
        DATA_VAR_NAME = 'generated_model_list';
    end
    
    methods
        function obj = ExploreCovExp(varargin)
            obj = obj@covexp.CorpusCovExp(varargin{:});
            obj.USE_MODELS_PATH = true;
        end
        
        
        function init_data(obj) 
            if covcfg.GENERATE_MODELS_LIST
                obj.generate_model_list();
            end
            
            generated_list = load(covcfg.GENERATE_MODELS_FILENAME);
            model_lists = generated_list.(obj.DATA_VAR_NAME);
            
            obj.populate_models(model_lists);
        end
        
        function populate_models(obj, models_list)
            obj.models = models_list(:, 1);
            obj.models_path = models_list(:, 2);
        end
        
        function generate_model_list(obj)
            obj.l.info('Generating model list...');
            models_and_dirs = utility.dir_process(covcfg.EXPLORE_DIR, '*.slx', obj.EXPLORE_SUBDIRS, {});
            
            model_names = cellfun(@(p)utility.strip_last_split(p, '.'), models_and_dirs(:, 1), 'UniformOutput', false);
            models_and_dirs(:, 1) = model_names;
            
            obj.save_generated_list(models_and_dirs);
        end
        
        function save_generated_list(obj, generated_model_list) %#ok<INUSD>
            save(covcfg.GENERATE_MODELS_FILENAME, obj.DATA_VAR_NAME);
        end
    end
    
end


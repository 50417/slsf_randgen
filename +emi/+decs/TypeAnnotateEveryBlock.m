classdef TypeAnnotateEveryBlock < emi.decs.DecoratedMutator
    %TYPEANNOTATEEVERYBLOCK Force all block's INPUT data-type
    %   To prevent data-type back-propagation, place a Data-type Converter
    %   block before each block's each input port, and fixate the output
    %   data-type of the DTC block.
    
    methods
        function preprocess_phase(obj) 
            %% Insert DTC before all blocks' all input ports
            target_blocks = obj.mutant.blocks{2:end,1}; % First one is the model itself?
            
            function ret = helper(blkname)
                blkname = [obj.mutant.sys '/' blkname];
                
                [~,sources,~] = emi.slsf.get_connections(blkname, true, false);
                
                self_as_destination = emi.slsf.create_port_connectivity_data(blkname, size(sources, 1), 0);
                ret = obj.mutant.add_DTC_before_block(blkname, sources, self_as_destination);
            end
            
            cellfun(@helper,target_blocks);
        end
    end
end

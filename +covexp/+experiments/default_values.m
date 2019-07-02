function ret = default_values(varargin)
%writes 

[t,s] = sldiagnostics('lale','CountBlocks');
original_num_block = s(1).count; % Total number of blocks in the model : details on https://blogs.mathworks.com/simulink/2009/08/11/how-many-blocks-are-in-that-model/
original_num_block

fid = fopen('lale.mdl');
fid_w = fopen('processed.mdl','wt');
tline = fgetl(fid);

%Striping out duplicate whitespaces and saving it in processed.mdl file
while ischar(tline)
    tline = strip(tline);
    tline = regexprep(tline,'[ |\t]+',' ');
    fprintf(fid_w,'%s\n',tline);
    %disp(tline)
    tline = fgetl(fid);
end

fclose(fid);
fclose(fid_w);
%Assertion to ensure the number of block was not changed
[t1,s1] = sldiagnostics('processed','CountBlocks');
original_num_block_processed = s1(1).count; % Total number of blocks in the model : details on https://blogs.mathworks.com/simulink/2009/08/11/how-many-blocks-are-in-that-model/
original_num_block_processed

%Figuring out default values
default_value = {};
count=0;
fid = fopen('processed.mdl','r');
tline = fgetl(fid);
while ischar(tline)
    count=count+1
    %Reads from a file
    file_id  = fopen('processed.mdl','r');
    f=fread(file_id,'*char')';
    fclose(file_id);
    
    
    if strcmp(tline,'Model {') || ~isempty(regexp(tline,'Name')) || ~isempty(regexp(tline,'BlockType')) || any(strcmp(default_value,tline)) 
        tline = fgetl(fid);
        continue
    end
    %Removing line from the file.
   f = regexprep(f,tline,'');
    for k=1:length(default_value)
       f = regexprep(f,default_value{k},'');
    end
    
    fwrite_id  = fopen('processed_removed.mdl','w');
    fprintf(fwrite_id,'%s',f);
    fclose(fwrite_id);
   
    try
    %if number of blocks is unchanged
    [t2,s2] = sldiagnostics('processed_removed','CountBlocks');
    original_num_block_removed = s2(1).count; % Total number of blocks in the model : details on https://blogs.mathworks.com/simulink/2009/08/11/how-many-blocks-are-in-that-model/
     close_system('processed_removed')
    catch ME
       
        if(strcmp(ME.identifier,'Simulink:Commands:LoadMdlInvalidFile'))
            tline = fgetl(fid);
            continue
        else
            tline
            ME
            tline = fgetl(fid);
          
            continue
            
        end
        
    end
   
    if original_num_block==original_num_block_removed
        default_value{end+1} = tline;
 
    end   
    
    
    tline = fgetl(fid);
end

for i=1:length(default_value)
    default_value{i}
end
end


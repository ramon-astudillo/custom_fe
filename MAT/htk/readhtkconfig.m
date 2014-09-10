% function config = readhtkconfig(config_path_cell)
%
% Reads a cell of strings containing paths of HTK's config files to a
% structure. It does not check if the fields are valid in HTK. It
% converts the values to numbers when possible.
%
% Input: config_path_cell cell of strings containing paths to config files
%
% Output: config          structure with parameters as fields, lower case
%
% It admits a special field CFF_FROM_CONFIG_PATH. When set to true, the 
% folder path of the current config file will be set as CUSTOM_FEATS_FOLDER
% variable. This is the variable indicating Matlab where the definition of
% the Matlab custom front-end is placed.
%
% Ramon F. Astudillo 

function config = readhtkconfig(config_path_cell)

config = []; 
for c = 1:length(config_path_cell)
    % Get config path
    config_path = config_path_cell{c};
    % TRY TO READ IT AS A FILE
    fid = fopen(config_path);
    if fid ~= -1  
        config_text=fscanf(fid,'%c');   
        fclose(fid);
    else
        error('Could not open config file %s',config_path)
    end
    % EXTRACT ARGUMENT AND VALUE
    items = regexp(config_text,'([^\n]+)=([^\n]*)\n','tokens');
    % PROCESS ARGUMENT VALUE ONE BY ONE
    for i=1:length(items)
        % IGNORE COMMENTS
        if regexp(items{i}{1},'^\s*#.*','once')
            continue
        end
        
        % GET VALUE
        fieldvalue   = strtok(strtrim(items{i}{2}),'#');
        fieldname    = strtrim(lower(items{i}{1}));

        % SPECIAL CASE, EXTRACT CUSTOM_FEATS_FOLDER FROM CONFIG PATH
        if strcmp(fieldname,'cff_from_config_path')...
           && strcmp(fieldvalue,'T')
            config.('custom_feats_folder') = fileparts(config_path);
        else
            % WATCH FOR SPECIAL CASE, VALUE IS SOURROUNDED BY ' '
            special_case = regexp(fieldvalue,'^''(.*)''$','tokens','once');
            if ~isempty(special_case)
               % Store it without ' '
               config.(fieldname)= special_case{1};
               continue
            end
            % TRY TO READ ARGUMENT AS A NUMBER
            % Note: Will fail with values that can be mistaken by the imaginary
            % unit \<i\> \<j\>
            if strcmp(fieldvalue,'i') || strcmp(fieldvalue,'j')
                error('The characters i or j are ambiguous as config values')
            end
            fetch = str2num(fieldvalue);
            if isempty(fetch)
                config.(fieldname) = strtrim(fieldvalue);
            else
                config.(fieldname) = fetch;
            end
        end
    end  
end

% Check feature extraction folder is given and it exists
if ~isfield(config,'custom_feats_folder') 
    error(['EITHER CFF_FROM_CONFIG_PATH or CUSTOM_FEATS_FOLDER must' ...
             'be specified inside of the config file given with -C']);
elseif ~exist(config.custom_feats_folder,'dir'); 
    error('CUSTOM_FEATS_FOLDER %s does not exist',...
            config.custom_feat_folder);
end

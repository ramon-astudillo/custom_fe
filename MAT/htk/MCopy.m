% function MCopy(HCopy_UP_FOLDER,HCopy_args)
%
% Matlab version of HTK HCopy executable that calls Matlab code to perform
% feature extraction. It also has some external dependencies like the
% sftf_up_tools or voicebox toolboxes, see installation instructions for 
% the custom_fe tools.  
%
% Input: HCopy_UP_FOLDER   string with path to the folder where the MCopy
%                          tools are, typically ./custom_fe/MAT/htk/
%
%        HCopy_args        string with the arguments of a standard HTK call          
%                           
% In HCopy_args a configuration file must always be specified with -C
% this configuration must contain the field CUSTOM_FEATS_FOLDER pointing
% to a folder where the feature extraction is defined by two functions
%
% init_feature_extraction.m   Will be called outside the file loop. Use it
%                             for file independent, computationally heavy,
%                             initializations. Parameters are stored in
%                             the structure config_FE
%
% feature_extraction.m        Will be called for each file path along with
%                             config_FE as additional argument   
% 
% An alternative is to set CFF_FROM_CONFIG_PATH = T. In this case the 
% folder path of the current config file will be set equal to
% the CUSTOM_FEATS_FOLDER variable. 
%
% See HCopy_UP_FOLDER/MAT/custom/IS2014/ for an example of this function
%
% MCopy supports HTK -C and -S options as well as a single source and 
% target pairs (multiple source/target pairs NOT supported unlike HTK)
%
% Three non-HTK options are also provided
%
% -resume   If target features file exists, skip it        
% -debug    When launching MCopy, it inserts a breakpoint at the beginning
% -up       It signals the feature extraction to append the variance of
%           the features by setting config_FE field UNC_PROP to 1. This has
%           to be implemented inside of feature_extraction.m
%
%
% Examples:
% 
% addpath('custom_fe/MAT/htk/');
% Mcopy(['MAT', ... 
%        '-C custom_fe/MAT/custom/MFCC/config', ... 
%        '-S files.list']);
%
% addpath('custom_fe/MAT/htk/');
% Mcopy(['MAT', ... 
%        '-C custom_fe/MAT/custom/MFCC/config', ... 
%        'source.wav target.mfc -debug']);
%
% Ramón F. Astudillo 

function MCopy(HCopy_UP_FOLDER,HCopy_args)

% Add code for basic utilities
addpath([HCopy_UP_FOLDER '/voicebox/']) % HTK tools from the voicebox tools
addpath([HCopy_UP_FOLDER '/htk/'])      % Other HTK tools

% Parse HTK call
HTK_call    = parse_HTK_args(HCopy_args);
total_files = length(HTK_call.source_files);

% Basic debug mode, stop
if HTK_call.debug_mode 
    dbstop in MCopy at 73
end

% Read HTK config(s), specified with the -C option
HTK_config = readhtkconfig(HTK_call.config_files);

% Add custom features code, specified inside of the config file
addpath(HTK_config.custom_feats_folder)

% Set Uncertainty Propagation to true if external flag "-up" used
HTK_config.unc_prop = HTK_call.unc_prop;

% INITIALIZE FEATURE EXTRACTION CONFIG
% Watch for variable number of arguments (backwards compatibility)
if nargin('init_feature_extraction_config') == 2 
    config_FE = init_feature_extraction_config(HCopy_UP_FOLDER,HTK_config);
else
    config_FE = init_feature_extraction_config(HTK_config);
end

% GET HTK FEATURES FORMAT PARAMETERS
[htk_format, fp] = get_HTK_headerparam(config_FE);

% INFORM USER
fprintf('\ndebug_mode  = %d\n',HTK_call.debug_mode)
fprintf('resume_mode = %d\n',HTK_call.resume_mode)
fprintf('unc_prop    = %d\n\n',HTK_call.unc_prop)
if isempty(HTK_call.scp_file)
    fprintf(['Transforming %s -> %s\n' ... 
             'into features in HTK format using %s\n'],... 
              HTK_call.source_files{1},HTK_call.target_files{1},...
              HTK_config.custom_feats_folder);
else
    fprintf(['Transforming %d speech files %s\n' ... 
             'into features in HTK format using %s\n'],...
             total_files,HTK_call.scp_file,...
             HTK_config.custom_feats_folder);
end
fprintf('Transfoming %d speech files into features in HTK format\n',...
        total_files);
    
% Accumulate stats     
avtime      = 0;
n_files     = 0;

% FOR EACH FILE
for i=1:total_files
    tic
    
    % IF RESUME MODE AND FILE EXISTS, SKIP IT
    if HTK_call.resume_mode && exist(HTK_call.target_files{i},'file')
        % INFO
        if ~mod(i,fix(total_files*0.001))
            fprintf(['RESUME_MODE ON, skipping %d already extracted' ...
                     ' files\n'],i);
        end
        continue 
    end
    % IF THERE IS A TARGET FOLDER AND IT DOES NOT EXIST, CREATE IT
    [target_folder,HTK_call.target_basename] = fileparts(HTK_call.target_files{i});
    if ~isempty(target_folder) && ~exist(target_folder,'dir')     
        mkdir(target_folder)
    end

    % READ AUDIO
    % Note that if DIRHA's microphone selection used, OTHER channels might
    % be read instead inside feature_extraction.m
    if isempty(config_FE.mic_sel)
        y_t = readaudio(HTK_call.source_files{i}, config_FE.byteorder,...
                        config_FE.in_fs, config_FE.fs);
    else
        y_t = [];
    end
 
    % FEATURE EXTRACTION
    % Make file names accessible inside feature extraction. 
    config_FE.target_file = HTK_call.target_files{i};  
    config_FE.source_file = HTK_call.source_files{i};  
    Features              = feature_extraction(y_t, config_FE);
    
    % WRITE FILES IN HTK FORMAT 
    writehtk(HTK_call.target_files{i},Features',config_FE.fp,config_FE.htk_format)
    
    % INFORM USER
    n_files = n_files+1;
    avtime  = (avtime*(n_files-1)+toc)/n_files;
    % Inform if already processed i*perc samples
    if ~mod(i,ceil(total_files*0.01))
        % Inform about progress
        time    = clock;
        time(6) = time(6) + (total_files - i)*avtime;
        % Expected finishing time
        eft = datestr(datenum(time));
        fprintf('\r%d/%d files EFT:%s [%2.2f s per file]',i, ...
                total_files,eft,avtime);
    end
end
fprintf('\n')
exit(0)

%
% SUBFUNCTIONS
%

% HTK_call = parse_HTK_args(HCopy_args)
%
%  Parses HTK call, returning arguments and flags in a structure

function HTK_call = parse_HTK_args(HCopy_args)
                                     
% Initialize
HTK_call.config_files = {};
HTK_call.debug_mode   = 0;
HTK_call.resume_mode  = 0;
HTK_call.unc_prop     = 0;
no_files              = 1;
%
while ~isempty(HCopy_args)
    % Next argument
    [arg,HCopy_args] = strtok(HCopy_args);
    % Debug mode
    if strcmp(arg,'-resume') 
        HTK_call.resume_mode = 1;
        
    % Debug mode
    elseif strcmp(arg,'-debug') 
        HTK_call.debug_mode = 1;
        
    % Uncertainty Propagation
    elseif strcmp(arg,'-up') 
        HTK_call.unc_prop = 1;
        
    % Argumentless options 
    elseif strcmp(arg,'-A') || strcmp(arg,'-D') 
        % nothing
        
    % Argument option to ignore       
    elseif strcmp(arg,'-T') 
        [arg,HCopy_args] = strtok(HCopy_args);
        
    % Config file   
    elseif strcmp(arg,'-C')
        % Next arg is config
        [arg,HCopy_args] = strtok(HCopy_args);
        HTK_call.config_files{end+1} = arg;
        
    % Script file   
    elseif strcmp(arg,'-S')
        % Next arg is scp file
        [HTK_call.scp_file,HCopy_args] = strtok(HCopy_args);
        % Read SCP file into a cell
        [HTK_call.source_files, ...
            HTK_call.target_files] = readscp(HTK_call.scp_file,'T',1,...
                                             'forHCopy',1);
        no_files = 0;
        
    % if it is an existing filename and its followed by a target, then we 
    % assume a source target pair 
    elseif exist(arg,'file') &&...
           isempty(regexp(arg,'-resume|-debug|-up|-A|-T|-C|-S','once'))
        % Current arg is source, next arg is target
        HTK_call.source_files = {arg};
        HTK_call.scp_file     = '';
        [tg,HCopy_args]       = strtok(HCopy_args);
        HTK_call.target_files = {strtok(tg)};
        no_files = 0;
        
    % Otherwise exit
    else
         error('%s is not a supported option or existing source file', arg);
    end
end
% Check files were specified as either SCP file or arguments
if no_files
    error(['Input files must be specified either in a list with -S or' ...
           'as a single source target pair']);
end

% function [htk_format, fp] = get_HTK_headerparam(config_FE)
%
% Given a config file, it determines targetkind and frame period to be used
% with writehtk.m function.

function [htk_format, fp] = get_HTK_headerparam(config_FE)

% DETERMINE TARGETKIND IN NUMERIC FORM 
% The default feature extraction is MFCC_D_A_Z_0
if ~isfield(config_FE,'targetkind')
    htk_format = targetkind2num('MFCC_D_A_Z_0');
    % htk_format = 11014;
else
    htk_format = targetkind2num(config_FE.targetkind);
end

% DETERMINE FRAME PERIOD IN 
if isfield(config_FE,'windowsize') && ...
   isfield(config_FE,'overlap') && ...
   isfield(config_FE,'fs')
    fp = (config_FE.windowsize-config_FE.overlap)/config_FE.fs;
elseif isfield(config_FE,'windowsize') && ...
   isfield(config_FE,'shift') && ...
   isfield(config_FE,'fs')
    fp = (config_FE.shift)/config_FE.fs;
elseif isfield(config_FE,'fp')
    fp = config_FE.fp;
else
    error(['Either windowsize, overlap (shift) and fs or fp have top be' ...
           ' provided to compute prame period duration']);
end

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
addpath([HCopy_UP_FOLDER '/voicebox/'])        % HTK tools from the voicebox tools
addpath([HCopy_UP_FOLDER '/htk/'])             % Other HTK tools
addpath([HCopy_UP_FOLDER '/kaldi-to-matlab/']) %  Tools for Kaldi 

% Parse HTK call
HTK_call    = parse_HTK_args(HCopy_args);
total_files = length(HTK_call.source_files);

% Basic debug mode, stop
if HTK_call.debug_mode 
    dbstop in MCopy at 73
end

% Read HTK config(s), specified with the -C option
HTK_config = readhtkconfig(HTK_call.config_files);
% Make first file available accessible inside init feature extraction.
HTK_config.target_file = HTK_call.target_files{1};
HTK_config.source_file = HTK_call.source_files{1};

% Add custom features code, specified inside of the config file
addpath(HTK_config.custom_feats_folder)

% Set Uncertainty Propagation to true if external flag "-up" used
HTK_config.unc_prop = HTK_call.unc_prop;

% INITIALIZE FEATURE EXTRACTION CONFIG
% Watch for variable number of arguments (backwards compatibility)
if nargin('init_feature_extraction_config') == 3
    config_FE = init_feature_extraction_config(HCopy_UP_FOLDER, ...
                                               HTK_config, ...
                                               HTK_call);
elseif nargin('init_feature_extraction_config') == 2 
    config_FE = init_feature_extraction_config(HCopy_UP_FOLDER,HTK_config);
else
    config_FE = init_feature_extraction_config(HTK_config);
end

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
    if isempty(config_FE.mlf_mic_sel)
        y_t = readaudio(HTK_call.source_files{i}, config_FE.byteorder,...
                        config_FE.in_fs, config_FE.fs);
    else
        y_t = [];
    end
 
    % FEATURE EXTRACTION
    % Make file names accessible inside feature extraction. 
    config_FE.target_file = HTK_call.target_files{i};  
    config_FE.source_file = HTK_call.source_files{i};  
    [Features, vad]       = feature_extraction(y_t, config_FE);
    
    % WRITE FILES IN HTK FORMAT 
    if strcmp(config_FE.targetformat, 'HTK')
        writehtkfeatures(Features, vad, config_FE, HTK_call.target_files{i});
    elseif strcmp(config_FE.targetformat, 'KALDI')
        features                  = struct('utt',cell(1),'feature',cell(1));
        features.utt{1}     = HTK_call.target_files{i};
        features.feature{1} = Features;
        writekaldifeatures(features, HTK_call.target_files{i});
    else
        error('Unknown TARGETFORMAT %s', config_FE.targetformat)
    end
    
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


% function writefeatures(Features, vad, config_FE)
%
% Write features in HTK format. If a cell provided, write a file per 
% element of the cell. If vad not empty write beginning and end for each 
% file

function writehtkfeatures(Features, vad, config_FE, target_file)


if iscell(Features)
    for c=1:length(Features)
        % Write file in HTK format
        [dirn,basen,type]=fileparts(target_file);
        % Write a text file with vad information
        if ~isempty(dirn)
            writehtk([dirn '/' basen '.' num2str(c) type],Features{c}',config_FE.fp,config_FE.htk_format)
        else
            writehtk([basen '.' num2str(c) type],Features{c}',config_FE.fp,config_FE.htk_format)
        end
        if ~isempty(vad)
            [dirn,basen]=fileparts(target_file);
            if ~isempty(dirn)
                fid=fopen([dirn '/' basen '.' num2str(c) '.vad'],'w');
            else
                fid=fopen([basen '.' num2str(c) '.vad'],'w');
            end
            fprintf(fid,'%s',vad{c});
            fclose(fid);
        end
    end
else
    % Write file in HTK format
    writehtk(target_file,Features',config_FE.fp,config_FE.htk_format)
    % Write a text file with vad information
    if ~isempty(vad)
        [dirn,basen]=fileparts(target_file);
        if isempty(dirn)
            fid = fopen([basen '.vad'], 'w');
        else
            fid = fopen([dirn '/' basen '.vad'], 'w');
        end
        fprintf(fid,'%s',vad);
        fclose(fid);
    end
end

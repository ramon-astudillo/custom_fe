% This function prepares the fature extraction. It is called before any 
% file has been processed.
%
% Input:  work_path  String containing path of the ./custom_fe/MAT/ folder
% Input:  config     Structure containing the config variables passed to 
%                    the HCopy call with the -C options 
%
% Output: config     Structure that will be available to 
%                    feature_extraction.m to use the info here computed
%
% Ramon F. Astudillo Sept 2013

function config = init_feature_extraction_config(work_path,config,htk_call)

% Matlab paths needed
addpath([work_path '/stft_up_tools/mfcc_up']) % STFT-UP
addpath([work_path '/stft_up_tools/stft'])    % STFT
addpath([work_path '/stft_up_tools/speech_enhancement']) % speech enhanc.
addpath([work_path '/voicebox'])                   % HTK interfaces
addpath([work_path '/dirha/']) % DIRHA-specific tools

% SUPPORTED HTK FIELDS AND DEFAULT VALUES IF ADMITTED
% use NaN as Python's None
HTK_supp = struct(...
    'sourcerate' , NaN,...
    'targetrate' , NaN,...
    'windowsize' , NaN,...
    'deltawindow', NaN,...
    'accwindow'  , NaN,...
    'targetkind' , 'USER',...
    'preemcoef'  , 0.97,...
    'usehamming' , 'T',...
    'usepower'   , 'F',...
    'numchans'   , 23,...
    'numceps'    , 12,...
    'byteorder'  , 'VAX',...
    'ceplifter'  , 22);

% ADDITIONALLY NON-HTK SUPPORTED FIELDS AND DEFAULT VALUES IF ADMITTED
Extra_supp = struct(...
    'target_file'        ,'',...
    'source_file'        ,'',...
    'custom_feats_folder', NaN,... 
    'separate_events'    ,  0,...     
    'in_fs'              , -1,...
    'fs'                 , NaN,...
    'shift'              , NaN,...
    'nfft'               , NaN,...
    'byteorder_raw'      , 'littleendian',...
    'init_time'          , 0.1,...
    'noise_estimation'   , '',...
    'iup'                , 0,...
    'enhancement'        , '',...
    'mlf_vad'            , '',...
    'mlf_mic_sel'        , '',...
    'mlf_mic_align'      , '',...
    'unc_prop'           , 0,...
    'do_debug'           , 0,...
    'do_up'              , 0); 

% Complete config
config = complete_defaults(config, HTK_supp, Extra_supp);

%
% READ MLF if provided
%

if ~isempty(config.mlf_mic_align)
    mlf_path = config.mlf_mic_align;    
elseif ~isempty(config.mlf_mic_sel)
    mlf_path = config.mlf_mic_sel; 
elseif ~isempty(config.mlf_vad)
    mlf_path = config.mlf_vad;     
else
    mlf_path = '';
end

if ~isempty(mlf_path)
    % DIRHA SPECIFIC PARSING OF MLF PATH
    % Try to retrieve DIRHA parameters. If sucessful check for special tokens in
    % mlf name and replace them and note that this is a dirha corpus
    [root, lang, set, sim, room, device, mic, typ, fs] ...
        = get_dirha_path(config.source_file);
    if ~isempty(lang)
        mlf_path     = strrep(mlf_path,'<dirha_lang>',upper(lang));
        mlf_path     = strrep(mlf_path,'<dirha_sets>',set);
    end
    config.mlf_trans = readmlf(mlf_path);
end

%
% FEATURE EXTRACTION
%

% Initialize MFCCs (compute Mel-fiterbank and DCT matrices)
[config.W,config.T]  = init_mfcc_HTK(config);

% TODO: Move these to the config file

% Additional needed fields
config.usepower      = 'F';      % Magnitude MFCCs
config.melfloor      = exp(-10); % Mel-floor needs to be small for STFT-UP
config.simplediffs   = 'F';      % This is the default in HTK

% Fields that have no effect as long as variances are zero, but are set to 
% keep mfcc_up function happy
config.log_prop     = 'LOGN';   % 'LOGN': Log-normal/CGF approximation, 
                                % 'LOGUT': Unscented transform for the 
                                % logarithm propagation. 
config.diagcov_flag = 0;        % 0 = Full covariance after Mel-filterbank
                                % considered
config.min_var      = 1e-6;     % Floor for the uncertainty
config.Chik         = 2;        % Use Chi with one or two degrees of 
                                % freedom

% HTK format
% MFCC_0_D_A_Z used in the models (11014)
config.htk_format  = 6 + 8192 + 256 + 512 + 2048;

%
% SPEECH ENHANCEMENT
%

% IMCRA 
config.alpha     = 0.92;  % Decision-directed a priori SNR 
                          % smoothing parameter. 
config.dB_xi_min = -25;   % Minimum a priori SNR in dB
config.imcra     = init_IMCRA(config.nfft/2+1);
%
config.alpha_d   = config.imcra.alpha_d;

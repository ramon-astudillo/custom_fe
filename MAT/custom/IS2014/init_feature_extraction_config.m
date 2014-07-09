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

function config = init_feature_extraction_config(work_path,config)

% Matlab paths needed
addpath([work_path '/stft_up_tools/mfcc_up']) % STFT-UP
addpath([work_path '/stft_up_tools/stft'])    % STFT
addpath([work_path '/stft_up_tools/speech_enhancement']) % speech enhanc.
addpath([work_path '/voicebox'])                   % HTK interfaces
addpath([work_path '/dirha/']) % DIRHA-specific tools

% NOTE: The HTK configs do not provide SOURCERATE??
config.fs            = 16000;

% Initialize MFCCs (compute Mel-fiterbank and DCT matrices)
config               = init_stft_HTK(config);

% Initialize MFCCs (compute Mel-fiterbank and DCT matrices)
[config.W,config.T]  = init_mfcc_HTK(config);

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
config.alpha     = 0.92;                     % Decision-directed a priori SNR 
                                      % smoothing parameter. 
config.dB_xi_min = -25;                      % Minimum a priori SNR in dB
config.imcra     = init_IMCRA(config.nfft/2+1);
%
config.alpha_d   = config.imcra.alpha_d;

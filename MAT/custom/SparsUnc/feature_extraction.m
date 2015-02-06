% function x = feature_extraction(y_t, config)
%
% Implementation of sparsity based uncertainty as used in the challenge
%
% Francesco Nesta, Marco Matassoni, Ramon Fernandez Astudillo, "A FLEXIBLE
% SPATIAL BLIND SOURCE EXTRACTION FRAMEWORK FOR ROBUST SPEECH RECOGNITION 
% IN NOISY ENVIRONMENTS", In 2nd International Workshop on Machine Listening 
% in Multisource Environments (CHiME), pages 33-38, June 2013
%
% Input:  y_t       [T, C] matrix of C channels containing time domain signals
%                   of T samples
%                   
%                   IMPORTANT NOTE: When DIRHA meta-data used, the signal used
%                   in the end might NOT be y_t e.g. by channel selection               
%         
% Input:  config    Structure containing information pre-computed at 
%                   init_feature_extraction_config.m and previous stages
% 
% Output: x         [I, L] matrix containing features. I is the number of 
%                   features and L the number of analysis frames. if 
%                   separate_events = 1 x is a cell containing features for 
%                   each event 
%
% Outout: vad       string containing extra information. 
%
%
% Ramon F. Astudillo Feb2015

function [x, vad] = feature_extraction(y_t, config)

% This funtion needs initial estimations of signal and interference.  
[path, name, type] = fileparts(config.source_file);
target_path = [path '/' name '_enhanced_target' type];
if exist(target_path,'dir')
    error('%s does not exist (SparUnc needs a target estimate)', target_path)
end
noise_path  = [path '/' name '_enhanced_noise' type];
if exist(noise_path,'dir')
    error('%s does not exist (SparUnc needs a noise estimate)', noise_path)
end

% Read files
[y_t,fs] = wavread(config.source_file);
[d_t,fs] = wavread(noise_path);
[x_t,fs] = wavread(target_path);

% STFT
Y = stft_HTK(y_t,config);
D = stft_HTK(d_t,config);
X = stft_HTK(x_t,config);
% We use the ratio of amplitudes to attain an estimate of speech activity.
% This is just a way of doing so.
p = abs(X)./(abs(X) + abs(D));
% Get sizes
[K,L,n] = size(Y);

%
% PROPAGATION THROUGH FEATURE EXTRACTION
%

% STFT-UP solution for MFCCs
[mu_x,Sigma_x] = mfcc_spars_up(Y,p,config);
% Deltas and Accelerations
[mu_x,Sigma_x] = append_deltas_up(mu_x,Sigma_x,config.targetkind,...
                                  config.deltawindow,config.accwindow,...
                                  config.simplediffs);

% Cepstram mean substraction
if regexp(config.targetkind, '.*_Z_?')
    [mu_x,Sigma_x] = cms_up(mu_x,Sigma_x,config.targetkind);
end

% Append variances if solicted
if config.unc_prop
    x = [mu_x; Sigma_x];
else
    x = mu_x;
end
vad = '';

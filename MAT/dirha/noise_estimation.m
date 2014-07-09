% function Lambda_D = noise_estimation(d_t,config)
%
% Simple enhancement with Lambda_D and decision directed a priori SNR
% estimation. Provides the posterior of the Wiener filter
%
% Input: d_t        [T, 1] Noise signal in time domain
%
% Input:  config    Structure containing information pre-computed at 
%                   init_feature_extraction_config.m and previous statges
%
% Output: Lambda_D  [k, L] Noise variance estimate in STFT domain (one frame)
%
% Ramon F. Astudillo    

function Lambda_D = noise_estimation(d_t,config)

% STFT
Y        = stft_HTK(y_t,config);
L        = size(Y,2);
% Noise estimation by recursive smoothing
Lambda_D = abs(Y(:,1)).^2;
for l = 1:L
    Lambda_D = config.alpha_d*Lambda_D + (1-config.alpha_d)*abs(Y(:,l)).^2;
end

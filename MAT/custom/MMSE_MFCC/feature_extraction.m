% function x = feature_extraction(y_t, config)
%
% Implementation of a minimum mean square error (MMSE) in MFCC domain using 
% uncertainty propagattion following:
%
% R. F. Astudillo, R. Orglmeister, "Computing MMSE Estimates and Residual 
% Uncertainty directly in the Feature Domain of ASR using STFT Domain Speech 
% Distortion Models", IEEE Transactions on Audio, Speech and Language 
% Processing, Vol. 21 (5), pp 1023-1034, 2013
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

%
% SPEECH ENHANCEMENT WITH A WIENER FILTER
%

% STFT
Y = stft_HTK(y_t,config);

% INIT TIME frames are considered background
config.IS = floor(config.init_time*config.fs/config.shift);

% INITIALIZATION
% Get sizes
[K,L]   = size(Y);
% This will hold the Wiener estimated clean speech
hat_X_W = zeros(K,L);
% This will hold the residual estimation uncertainty, in other words
% the variance of the Wiener posterior
MSE     = zeros(size(Y));
% Initialize noise power
config.imcra.Lambda_D = abs(Y(:,1).^2);
% Initialize Gain and a posteriori SNR
GH1              = ones(K,1);
Gamma            = GH1;
% Loop over frames
for l=1:L
    % A posteriori SNR
    new_Gamma    = (abs(Y(:,l)).^2)./config.imcra.Lambda_D;   
    % Decision directed a priori SNR estimation, with lower bound
    xi           = config.alpha*(GH1.^2).*Gamma ... 
                 + (1-config.alpha)*max(new_Gamma-1,0);  
    xi           = max(xi,10^(config.dB_xi_min/20));
    % Update Gamma
    Gamma        = new_Gamma;
    % WIENER Gain
    GH1          = xi./(1+xi);
    % WIENER Posterior
    % Mean (Wiener filter)
    hat_X_W(:,l) = GH1.*Y(:,l);
    % Variance (residual MSE)
    MSE(:,l)  = GH1.*config.imcra.Lambda_D;

    % SNR ESTIMATION (I), yes it is done in this order
    % IMCRA estimation of noise variance
    config.imcra = IMCRA(config.imcra,Y(:,l),Gamma,xi); 
end

%
% FEATURE EXTRACTION / UNCERTAINTY PROPAGATION
%

% MFCC DOMAIN ENHANCEMENT
% Transform Wiener posterior through the MFCCs
[m_x,S_x] = mfcc_up(hat_X_W, MSE, config);
% Append deltas, accelerations
[m_x,S_x] = append_deltas_up(m_x,S_x,config.targetkind, config.deltawindow, ...
                             config.accwindow, config.simplediffs);
% Cepstram mean substraction
if regexp(config.targetkind, '.*_Z_?')

    % cms *only* in this segment
    [m_x,S_x] = cms_up(m_x,S_x);

end

% Append variances if solicted
if config.unc_prop
    x = [m_x; S_x];
else
    x = m_x;
end
vad = '';

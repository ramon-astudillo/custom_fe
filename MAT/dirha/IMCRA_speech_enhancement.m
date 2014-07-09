% function  [hat_X_W, Lambda] = IMCRA_speech_enhancement(y_t,Lambda_D,config)         
%
% Returns enhanced STFT of a signal attained by a Wiener filter and IMCRA 
% noise estimation, see
% 
% [1] I. Cohen, "Noise Spectrum Estimation in Adverse Environments: Improved Minima Controlled 
% Recursive Averaging", in IEEE Trans. on Speech and Audio Processing, Vol 11 (5), pp 1063-6676,
% 2003  
%
% The resulting minimum Mean Square Error (MSE) of the filter is returned as 
% well. This allows to derive other estimators such as MMSE-STSA, MMSE-LSA or 
% MMSE-MFCC see
%
% [2] R. F. Astudillo, R. Orglmeister, "Computing MMSE Estimates and Residual 
% Uncertainty directly in the Feature Domain of ASR using STFT Domain Speech 
% Distortion Models", IEEE Transactions on Audio, Speech and Language 
% Processing, Vol. 21 (5), pp 1023-1034, 2013
%
% Input: y_t       [T, 1] corrupted speech time domain signal
%
% Input: Lambda_D  [K, L] Initial noise estimate in STFT domain. K frequency 
%                  bins and L analysis frames       
%
% Input: config     structure containing at STFT and IMCRA configurations
%
% Output: hat_X_W  [K, L] Clean STFT estimate
%
% Output: Lambda   [K, L] MSE of the estimate
% 
% Ramón F. Astudillo

function  [hat_X_W, Lambda] = IMCRA_speech_enhancement(y_t,Lambda_D,config)         

% STFT
Y = stft_HTK(y_t,config);

% INITIALIZATION
% Get sizes
[K,L]            = size(Y);
% This will hold the Wiener estimated clean speech
hat_X_W          = zeros(K,L);
% This will hold the residual estimation uncertainty, in other words
% the variance of the Wiener posterior
Lambda           = zeros(size(Y));
% Initialize noise power
config.imcra.Lambda_D   = Lambda_D;
% Initialize Gain and a posteriori SNR
GH1              = ones(K,1);
Gamma            = GH1;
% Loop over frames
for l=1:L
    % A posteriori SNR
    new_Gamma    = (abs(Y(:,l)).^2)./config.imcra.Lambda_D;   % [1, eq.3]
    % Decision directed a priori SNR estimation, with lower bound
    xi           = config.alpha*(GH1.^2).*Gamma ... 
                 + (1-config.alpha)*max(new_Gamma-1,0);  % [1, eq.32]
    xi           = max(xi,10^(config.dB_xi_min/20));
    % Update Gamma
    Gamma        = new_Gamma;
    % WIENER Gain
    GH1          = xi./(1+xi);
    % WIENER Posterior
    % Mean (Wiener filter)
    hat_X_W(:,l) = GH1.*Y(:,l);
    % Variance (residual MSE)
    Lambda(:,l)  = GH1.*config.imcra.Lambda_D;

    % SNR ESTIMATION (I), yes it is done in this order
    % IMCRA estimation of noise variance
    config.imcra = IMCRA(config.imcra,Y(:,l),Gamma,xi); 
end

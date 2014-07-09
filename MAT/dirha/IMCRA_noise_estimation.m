% function config   = IMCRA_noise_estimation(d_t,config)
%
% Updates IMCRA minimum tracking using provided context
%
% Input: d_t        [T, 1] Noise signal in time domain
%
% Input: config     structure containing at STFT and IMCRA configurations
%
% Output: config    same config but with updated IMCRA parameters
%
% Ramón F. Astudillo

function config = IMCRA_noise_estimation(d_t,config)

% STFT
D               = stft_HTK(d_t,config);
L               = size(D,2);
% Reset IMCRA
config.imcra.l  = 0;
% Set context to the whole background segment
config.imcra.IS = L+1;
for l = 1:L
    config.imcra = IMCRA(config.imcra,D(:,l),[],[]);
end
% Use no further context
config.imcra.IS = 0;

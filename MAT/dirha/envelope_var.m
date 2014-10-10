function V = envelope_var(x_t, config)

% STFT
X = stft_HTK(x_t,config);
% MEL FILTERBANK
x = sparse(config.W)*abs(X);
% MEL-FLOOR
x(x<config.melfloor) =config.melfloor;
% LOGARITHM
x = log(x);
% Mean subtraction and back to Mel (Wolfe Ph.D Eq. 3.6)
x = exp(x-repmat(mean(x,2),1,size(x,2)));
% VAR
V = var(x.^(1/3),0,2);  

% function [y_t, d_t] = delay_and_sum(or_ref_mics)    
%
% Sums the aligned channels and corresponding background segments
%
% Input: or_ref_mics  cell of aligned  speech events produced by the 
%                     DIRHA_AED_and_MNP.m function when using field
%                     'OracleAlign'
%
% Output: y_t         sum of aligned signals (normalized by number of channels) 
%
% Output: d_t         sum of aligned preceding context, normalized and cropped
%                     to the shortest of the context 
%
% Ramón F. Astudillo

function [y_t, d_t] = delay_and_sum(or_ref_mics,byteorder,in_fs,fs)    

n_mics = length(or_ref_mics);

% Txts bounds can be one sample off sometimes due to the
% downsampling to 16KHz. We need to check all files for length in samples
% Get all lengths
Ts = zeros(n_mics,1);
for m=1:n_mics
    Ts(m) = or_ref_mics{m}{2}(end) - or_ref_mics{m}{2}(1);
end
% Check for different lengths
ds_crop = 0;
if ~all(Ts == Ts(1))
%    warning('DIRHA-GRID VADtxt have different lengths for the same even. I will purge last sample to make them match')
    min_t = min(Ts);
    ds_crop = 1;
end

%
% Apply VAD to extract each segment
%

% Initialize speech and background
if ds_crop
    y_t = zeros(min_t,1);
else
    y_t = zeros(length(or_ref_mics{1}{2}),1);
end
% Find the smallest background 
L_D = Inf;
for m=1:n_mics
    L_D = min(length(or_ref_mics{m}{3}), L_D);
end
d_t = zeros(L_D,1);

% For each aligned event captured by a microphone in the room
for m=1:n_mics
    sp_idx = or_ref_mics{m}{2};
    bg_idx = or_ref_mics{m}{3};
    tmp    = readaudio(or_ref_mics{m}{1},byteorder,in_fs,fs);
    if ds_crop
        y_t = y_t + tmp(sp_idx(1:min_t));
    else
        y_t = y_t + tmp(sp_idx);
    end
    % Crop to smallest background
    tmp2   = tmp(bg_idx);
    if L_D
        d_t = d_t + tmp2(end-(L_D-1):end);
    end
end
y_t = y_t/n_mics;
if L_D
    d_t = d_t/n_mics;
else
    d_t = [];
end

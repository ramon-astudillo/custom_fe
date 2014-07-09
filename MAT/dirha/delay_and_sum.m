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

function [y_t, d_t] = delay_and_sum(or_ref_mics)    

% GRID-DIRHA's Txts bounds are one sample off sometimes due to the
% downsampling to 16KHz. We need to check all files for length in samples
% Get all lengths
Ts = zeros(length(or_ref_mics{2}),1);
for m=1:length(or_ref_mics{1})
    Ts(m) = or_ref_mics{2}{m}(end) - or_ref_mics{2}{m}(1);
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
    y_t = zeros(length(or_ref_mics{2}{1}),1);
end
% Find the smallest background 
L_D = Inf;
for m=1:length(or_ref_mics{1})
    L_D = min(length(or_ref_mics{3}{m}), L_D);
end
d_t = zeros(L_D,1);

% For each aligned event captured by a microphone in the room
for m=1:length(or_ref_mics{1})
    sp_idx = or_ref_mics{2}{m};
    bg_idx = or_ref_mics{3}{m};
    tmp    = readaudio(or_ref_mics{1}{m});
    if ds_crop
        y_t = y_t + tmp(sp_idx(1:min_t));
    else
        y_t = y_t + tmp(sp_idx);
    end
    % Crop to smallest background
    tmp2   = tmp(bg_idx);
    if L_D
        % This actually misaligns the different contexts. It is left to 
        % obtain the exact results of the IS2014 baseline. Will be corrected
        % in posterior versions.
        d_t = d_t + tmp2(1:L_D,:);
    end
end
y_t = y_t/length(or_ref_mics{1});
if L_D
    d_t = d_t/length(or_ref_mics{1});
else
    d_t = [];
end

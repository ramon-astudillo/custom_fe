% function htk_format = targetkind2num(targetkind)
%
% Given a HTK's TARGETKIND parameters returns the numeric equivalent. See 
% voicebox's toolbox readhtk.m and writehtk.m functions for a reference
%
% Ramón F. Astudillo 

function htk_format = targetkind2num(targetkind)

% TYPES AND MODIFIERS ALLOWED IN HTK
types = {'WAVEFORM' 'LPC' 'LPREFC' 'LPCEPSTRA' 'LPDELCEP' 'IREFC' ...
    'MFCC' 'FBANK' 'MELSPEC' 'USER' 'DISCRETE' 'PLP' 'ANON'};
mods  = {'E' 'N' 'D' 'A' 'C' 'Z' 'K' '0' 'V' 'T'};
% Corresponding binary values for mods
mval  =  2.^(6:15);

% TYPE AND MODIFIERS OF THE FEATURE VECTOR
tokens = regexp(targetkind,'_','split');
% Lookup file type,  Check if type is known
idx_kind      = find(strcmp(types, tokens{1}));
if isempty(idx_kind)
    error('Unknown TARGETKIND %s', config_FE.targetkind)
end

% COMPUTE HTK FORMAT
% Type
htk_format = idx_kind-1;
% Used modifiers
for mod = {tokens{2:end}}
    if all(strcmp(mods, mod{1}) == 0)
        error('Unknown TARGETKIND modifier %s', mod{1})
    end
    htk_format = htk_format + mval(strcmp(mods, mod{1}));
end

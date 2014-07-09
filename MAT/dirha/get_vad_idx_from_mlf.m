% function [sp_idx,bg_idx] = get_vad_idx_from_mlf(mlf_path,audio_path,fs,shift)
%
% Reads HTKs MLF file containing the output of a voice activity detector
% for one single file. Note that there is a restriction on the format:
%
% THE FILE MUST CONTAIN ONLY SPEECH SEGMENTS, LABEL USED IS INDIFFERENT
%
% Input: mlf_path   string containing the path of the MLF   
%        audio_path string containing the path of the audio file
%        fs         sample frequency   
%        (shift)    shift of the STFT, if indices to STFT frames needed
%
% Output: sp_idx    cell with indices of each speech segment
%         bg_idx    cell with indices of each background segment
%
% Ramon F. Astudillo 

function [sp_idx,bg_idx] = get_vad_idx_from_mlf(mlf_path,audio_path,fs,shift)

% Default shift is 1 (for time domain samples)
if nargin < 4
     shift = 1;
end

% Conversion factor from HTK units to samples (shift=1) or STFT frames
conv_fac = fs/(1e7*shift);

% Read transcriptions
trans = readmlf(mlf_path);

% For each transcription, look for the transcription matching audio filename.
% If found then get the indices to the array and exit. Otherwise raise 
% error
found  = 0;
sp_idx = {}; 
bg_idx = {};
l      = 1;
for i=1:length(trans)
    % Translate HTK's wildcards to regular expressions
    file_trans = [strrep(strtok(trans(i).name,'.'),'*','.*') '.*'];
    if regexp(audio_path,file_trans)
        found = 1;
        % For each word in the transcription, get start and end and 
        % determine speech and background segments
        for j=1:length(trans(i).word)
            st = max(floor(conv_fac*trans(i).word(j).beg),1);
            ed = ceil(conv_fac*trans(i).word(j).ende);
            % Segments between speech periods are assumed background 
            if (st - l) > 1
                bg_idx{end+1} = (l:st);
                l             = ed+1;
            else
                bg_idx{end+1} = [];
                st     = l;
                l      = ed+1;
            end
            % This segment is all speech                  
            sp_idx{end+1} = (st:ed);
        end
        break
    end
end
% Raise error if no transcription found
if ~found
   error('No transcription found for file %s in mlf %s',audio_path,...
         mlf_path)
end

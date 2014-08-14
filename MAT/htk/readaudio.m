% function [x,fs] = readaudio(audio_file)
%
% Reads audio according to file termination
%
% Input: audio_file  string containing a path to a wav or raw file
% 
% Output: x          [T, C] matrix containing C channels of T samples
%
% Output: fs         sample frequency in Hz. Unknown for raw files 
%
% Ramon F. Astudillo 

function [x,fs] = readaudio(audio_file, machinefmt)

% For raw, default format is little endian see
% http://www.mathworks.com/help/matlab/ref/fopen.html
if nargin < 2
    machinefmt = 'n';
end

[dum,dum,type]=fileparts(audio_file);

% WAV
if regexp(type,'\.wav$')
    [x,fs]= wavread(audio_file);
% RAW
% Admits raw1, raw2. Useful for WSJ0 extraction (wv1, wv2 formats)     
elseif regexp(type,'\.raw[0-9]?$')
    fid = fopen(audio_file,'r', machinefmt);
    x   = fread(fid,inf,'int16');
    fclose(fid);
    fs = [];
else
    error('Unknown file type in %s',audio_file)
end

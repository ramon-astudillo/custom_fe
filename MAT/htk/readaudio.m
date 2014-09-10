% function [x,fs] = readaudio(audio_file)
%
% Reads audio according to file termination
%
% Input: audio_file  string containing a path to a wav or raw file
%
% Input: byteorder  Machine format
%
% Input: in_fs      If specified, raises error if input data does not match it  
%                   This is obligatry for RAW 
%
% Input: out_fs     If specified, downsample data to meet out_fs. Raise error
%                   if upsampling necessary           
% 
% Output: x         [T, C] matrix containing C channels of T samples
%
% Output: fs        sample frequency in Hz. Unknown for raw files 
%
% Ramon F. Astudillo 

function [x, out_fs, in_fs] = readaudio(audio_file, byteorder, in_fs, out_fs)

% For raw, default format is little endian see
% http://www.mathworks.com/help/matlab/ref/fopen.html
if nargin == 3
    out_fs    = -1;
elseif nargin == 2
    out_fs    = -1;
    in_fs     = -1;
elseif nargin == 1
    out_fs    = -1;
    in_fs     = -1;
    byteorder = 'n';
end

[dum,dum,type]=fileparts(audio_file);

% WAV
if regexp(type,'\.wav$')
    [x,fs]= wavread(audio_file);
    if (in_fs ~= -1) && (in_fs ~= fs)
        error('A frequency of %2.2f was specified but the wav has %2.2f', in_fs, fs)
    else
        in_fs = fs;
    end

% RAW
% Admits raw1, raw2. Useful for WSJ0 extraction (wv1, wv2 formats)     
elseif regexp(type,'\.raw[0-9]?$')
    if in_fs == -1
        error('For raw data is obligatory to specify sample frequency')
    end
    if strcmp(byteorder, 'NONVAX')
        fid = fopen(audio_file,'r', 'b');
    elseif strcmp(byteorder, 'VAX')
        fid = fopen(audio_file,'r', 'n');
    else
        error('Unknown config.machineformat %s', byteorder)
    end
 
    if fid == -1
        error('File %s could not be opened or found', audio_file)
    end
    x = fread(fid,inf,'int16');
    fclose(fid);
    fs = [];
else
    error('Unknown file type in %s',audio_file)
end

% Downsample if necessary
if out_fs ~= -1
    if out_fs > in_fs
        error('in_fs=%d > out_fs=%d Upsampling not allowed',in_fs,out_fs)
    end
    if mod(in_fs, out_fs)
        error('in_fs=%d is not a multiple of out_fs=%d',in_fs,out_fs)
    end 
    x = decimate(x,in_fs/out_fs);
else
    out_fs = in_fs;
end

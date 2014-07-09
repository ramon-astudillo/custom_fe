% function [sp_idx, bg_idx, in_room, room, dist_mic] = readmetadata(wav_path, seg)
% 
% Given a wav file from a DIRHA task it reads the corresponding meta-data file
% It also admits the path of the meta-data file directly.
%
% Input: file_path       Either the path of the wav or meta-data txt file
% Input  seg = 1         If one, tight oracle VAD returned, otherwise loose VAD 
% 
% Output: sp_idx         Cell  with indices to the speech events in the wav
%
% Output: bg_idx         Cell with indices to the background segments 
%                        preceding each speech event
%
% Output: in_room        Cell with flag indicating if the speech event took 
%                        place in the room were the mic is   
%
% Output: room           Room were the mic is
%
% Output: dist_mic       Cell with distance of the microphone to each speech
%                        even, in case they are in the same room
%
% Ramon F. Astudillo   

function [sp_idx, bg_idx, in_room, room, dist_mic] = readmetadata(file_path, seg)

% Default is tight VAD
if nargin < 2
    seg = 1;
end

% Check wether the wav file or directly the meta-data file were given
[dirname,basename,type]=fileparts(file_path);
if strcmp(type,'txt')
    meta_data_path = file_path;
else
    meta_data_path = strrep(file_path,'.wav','.txt');
end

% This will store the ground truth of speech in this room
sp_idx     = {}; 
bg_idx     = {}; 
in_room    = [];   % wether source is in the same room as this mike
room       = {};
dist_mic   = {};   % distance from source to this mike (assuming in room)

% Get room this mic is in
mic_room = regexp(meta_data_path,'.*/Mixed_Sources/+([^/]*)/.*','tokens','once');

% OPEN FILE FOR READING
fid = fopen(meta_data_path,'r');
if fid == -1
    error('File % s could not be opened or found', meta_data_path);
end
line    = fgetl(fid);  
n_line  = 0;
state   = '';
while line ~= -1 
    n_line =  n_line + 1;
    %
    % STATE MACHINE
    %    
    % NOT IN SOURCE
    if isempty(state)        
        % Enter source 
        if regexp(line ,'\s*<SOURCE>\s*')
            state = 'source';    
        elseif regexp(line ,'\s*<MICROPHONE>\s*')
            state = 'microphone';    
        end
    % IN SOURCE    
    elseif regexp(state, '.*source')
        % Exit source
        if regexp(line ,'\s*</SOURCE>\s*')
            source_room = ''; % to catch eventual bugs
            state = '';
        % Found out it is a speech source     
        elseif regexp(line ,'<name>sp_cmd\d+</name>')
            state = 'speech_source';     
        % IN SPEECH SOURCE 
        % Found the line where the room is specified
        elseif strcmp(state, 'speech_source') & ...
               regexp(line ,'\s*<IR>.*</IR>\s*')
            source_room = regexp(line, ['\s*<IR>.*(BEDROOM).*</IR>\s*|'...
                                        '\s*<IR>.*(KITCHEN).*</IR>\s*|'...
                                        '\s*<IR>.*(LIVINGROOM).*</IR>\s*|'...
                                        '\s*<IR>.*(BATHROOM).*</IR>\s*|'...
                                        '\s*<IR>.*(CORRIDOR).*</IR>\s*'],'tokens','once');
        % Found the line where the speech source time boundaries are 
        % specified    
        elseif strcmp(state, 'speech_source') & ...
               regexp(line ,'\s*<label=seg>\s*')
            % Next line contains boundaries
            line  = fgetl(fid);
            fetch = regexp(line, '(\d+)\s(\d+)\s.*','tokens','once'); 
            % Store boundaries
            if seg
                st             = str2double(fetch{1});
                ed             = str2double(fetch{2});
                sp_idx{end+1}  = (st:ed);
            end
            % Store room information
            in_room(end+1) = strcmpi(mic_room, source_room);
            room{end+1}    = source_room;
            if strcmpi(mic_room, source_room)
                dist_mic{end+1} = sqrt(sum((mic_pos - source_pos).^2));  
            else
                dist_mic{end+1} = 1e6;
            end      
        % Found the line where the speech source loose time boundaries are 
        % specified    
        elseif strcmp(state, 'speech_source') & ...
               regexp(line ,'\s*<label=txt>\s*')
            % Next line contains boundaries
            line  = fgetl(fid);
            fetch = regexp(line, '(\d+)\s(\d+)\s.*','tokens','once'); 
            % Store boundaries
            if ~seg
                st            = str2double(fetch{1});
                ed            = str2double(fetch{2});
                sp_idx{end+1} = (st:ed);
            end

        % Found position tag     
        elseif strcmp(state, 'speech_source') & ...
               regexp(line ,'\s*<pos>xs=[0-9\.]+ ys=[0-9\.]+ zs=[0-9\.]+ [^<]*</pos>\s*')
               fetch      = regexp(line ,'\s*<pos>xs=([0-9\.]+) ys=([0-9\.]+) zs=([0-9\.]+) [^<]*</pos>\s*','tokens','once');
               source_pos = [str2num(fetch{1}) str2num(fetch{2}) str2num(fetch{3})];

            
        end
    % IN MICROPHONE
    elseif strcmp(state, 'microphone')
        % exit microphone   
        if regexp(line ,'\s*</MICROPHONE>\s*')
            state = '';
        % Found position tag     
        elseif regexp(line ,'\s*<mic_pos>x=[0-9\.]+; y=[0-9\.]+; z=[0-9\.]+; \w*</mic_pos>\s*')
               fetch   = regexp(line ,'\s*<mic_pos>x=([0-9\.]+); y=([0-9\.]+); z=([0-9\.]+); \w*</mic_pos>\s*','tokens','once');
               mic_pos = [str2num(fetch{1}) str2num(fetch{2}) str2num(fetch{3})]; 
        end

    end
    % GET NEXT LINE            
    line = fgetl(fid);           
    % Empty lines should be treated as comments          
    if isempty(line) 
        line='#'; 
    end    
end
fclose(fid);
% Now we need to sort the commands as they are not so in the meta-data file
begs = zeros(length(sp_idx),1);
for i=1:length(sp_idx)
    begs(i) = sp_idx{i}(1); 
end
[dum, I] = sort(begs);
sp_idx   = {sp_idx{I}};
in_room  = in_room(I);
dist_mic = {dist_mic{I}};
room     = {room{I}};
% Finally, determine background as the segments between speech
t      = 1;
bg_idx = {};
for i=1:length(sp_idx) 
    st = sp_idx{i}(1);
    % Store preceeding context only if exists
    if st-1 > t
        bg_idx{end+1} = (t:st-1);
    else
        bg_idx{end+1} = [];
    end
    t = sp_idx{i}(end)+1;
end

% function [mic, sources] = readmetadata(wav_path)
% 
% Given a wav file from a DIRHA task it reads the corresponding meta-data file
% It also admits the path of the meta-data file directly.
%
% Input: file_path       Either the path of the wav or meta-data txt file
% 
% Output: mic            Structure with MICROPHONE tags as fields
%
% Output: sources        Structure with SOURCE names as fields. Each 
%                        sources.name contains the correspodning fields.
%
% Output: globals        Cell with ordered account of events according to
%                        the GLOBAL tag
%
% Ramon F. Astudillo   

function [mic, sources, globals] = readmetadata(file_path, downsample)

if nargin < 2;
    downsample = 0;
end

% Check wether the wav file or directly the meta-data file were given
[dirname,basename,type]=fileparts(file_path);
if strcmp(type,'txt')
    meta_data_path = file_path;
else
    meta_data_path = strrep(file_path,'.wav','.txt');
end

% This will store the ground truth of speech in this room
mic     = [];
sources = [];
globals = [];

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

    % NOT IN SOURCE OR MIC
    if isempty(state)        
        % Enter source (speech or non speech)
        if is_tag(line,'SOURCE')
            % Read an extra line to determine which type of source and name
            n_line =  n_line + 1;
            line   = fgetl(fid);
            if ~is_tag(line,'name')
                error(['Error while parsing %s in line %d, expected a name '...
                       'tag after SOURCE'],meta_data_path,n_line)
            end
            source_name                       = get_tagvalue(line);
            sources.(source_name).name = source_name; 
            sources.(source_name).file = mic.file;
            if regexp(source_name,'sp_.*')
                state = 'speech_source';     
            else
                state = 'source';               
            end
        % Enter mic    
        elseif is_tag(line,'MICROPHONE') 
            state = 'microphone';
        elseif is_tag(line,'GLOBAL')
            state   = 'global';
            % This will store the scene
            globals = {};
        end

    % IN SOURCE    
    elseif regexp(state, '.*source')
        % Exit source
        if is_tag(line,'/SOURCE')
            state       = '';
        % Fields common to all sources of the from tag value /tag 
        elseif is_tag(line, {'T60', 'SNR'}) 
            [tag, value]                       = get_tag(line);
            sources.(source_name).(tag) = value;
        % Start of event           
        elseif is_tag(line, {'begin_sample'}) 
            [tag, value] = get_tag(line);
            if downsample
                sources.(source_name).(tag) = ceil(str2num(value)*downsample); 
            else
                sources.(source_name).(tag) = str2num(value); 
            end
        % End of event    
        elseif is_tag(line, {'end_sample'}) 
            [tag, value] = get_tag(line);
            if downsample
                sources.(source_name).(tag) = floor(str2num(value)*downsample);
            else
                sources.(source_name).(tag) = str2num(value);
            end  
        % Found ROOM tag
        elseif is_tag(line, 'IR')
            % Ignore right now            
        % Found position tag     
        elseif is_tag(line, 'pos')
            fetch= regexp(line , ['\s*<pos>xs=([0-9\.]+) ys=([0-9\.]+) '...
                                  'zs=([0-9\.]+) REF=REF_(\w*)</pos>\s*'],'tokens',...
                                  'once');
            sources.(source_name).pos = [str2num(fetch{1}) ...
                                         str2num(fetch{2}) ...
                                         str2num(fetch{3})];  

            % Fix for short-name notation
            if strcmp(fetch{4},'BAT')
                sources.(source_name).('room') = 'BATHROOM'
            elseif strcmp(fetch{4},'BEDROO') || strcmp(fetch{4},'BED')
                sources.(source_name).('room') = 'BEDROOM';
            elseif strcmp(fetch{4},'CORR') | strcmp(fetch{4},'COR')
                sources.(source_name).('room') = 'CORRIDOR';
            elseif strcmp(fetch{4},'KIT')
                sources.(source_name).('room') = 'KITCHEN';
            elseif strcmp(fetch{4},'LIV') 
                sources.(source_name).('room') = 'LIVINGROOM';
            else
                sources.(source_name).('room') = fetch{4};
            end

        % Field spanning various lines: VAD boundaries  
        elseif is_tag(line, 'label=seg') 
            % Next line contains boundaries
            line  = fgetl(fid);
            sources.(source_name).seg = [];
            while ~is_tag(line,'/label=seg') 
                fetch = regexp(line, '(\d+)\s(\d+)\s.*','tokens','once');
                st    = str2double(fetch{1});
                ed    = str2double(fetch{2});
                if downsample
                    st = ceil(st*downsample);
                    ed = floor(ed*downsample);
                end
                sources.(source_name).seg = [sources.(source_name).seg ...
                                             (st:ed)];
                % Get next line
                line   = fgetl(fid);
                n_line = n_line +1;
            end
            
            % Store loose boundaries
            sources.(source_name).txt = ...
                sources.(source_name).begin_sample:...
                sources.(source_name).end_sample;
            
            % Store room information
            sources.(source_name).in_room = strcmpi(strtok(mic.room), ...
                sources.(source_name).room);
            if sources.(source_name).in_room
                sources.(source_name).dist_mic = ...
                     sqrt(sum((mic.pos - sources.(source_name).pos).^2));  
            else
                sources.(source_name).dist_mic = Inf;
            end    

        % Special speech fields Loose boundaries
        elseif strcmp(state, 'speech_source') & is_tag(line, 'SPK_ID')
            % use directly begin, end
            [tag, value]                = get_tag(line);
            sources.(source_name).(tag) = value;
        elseif strcmp(state, 'speech_source') & is_tag(line,'label=txt')
            % fast forward
            while ~is_tag(line,'/label=txt')
                % Get next line
                line  = fgetl(fid);
                n_line  = n_line +1;
            end
        elseif strcmp(state, 'speech_source') & is_tag(line,'label=wrd')
            % fast forward
            while ~is_tag(line,'/label=wrd')
                % Get next line
                line  = fgetl(fid);
                n_line  = n_line +1;
            end            
        % Special skip geneder/gender typo in DIRHA sim ...
        elseif strcmp(state, 'speech_source') &...
                regexp(line,'\s*<geneder>[^<]*</gender>\s*')
            % do nothing
         
        % ... which is actually ok on the DIRHA-GRID
        elseif strcmp(state, 'speech_source') & is_tag(line,'gender')
            % do nothing    
            
        % Unknown tag
        else
            error('Error while parsing %s in line %d, unknown SOURCE tag %s',...
                meta_data_path,n_line,line)
        end

    % IN GLOBAL
    elseif strcmp(state, 'global')
        % Exit microphone   
        if is_tag(line,'/GLOBAL') 
            state   = ''; 
        elseif regexp(line ,'\d* \d* [A-Za-z_\s0-9]*')
            cosa           = regexp(strtrim(line) ,['(\d*) (\d*)' ...
                                    ' ([A-Za-z_\s0-9]*)'],  'tokens','once');
            globals{end+1} = {str2num(cosa{1}) str2num(cosa{2}) ...
                              regexp(cosa{3},' ','split')};
        else
            error('Error while parsing %s in line %d, unknown GLOBAL info %s',...
                meta_data_path,n_line,line)
        end   
            
    % IN MICROPHONE
    elseif strcmp(state, 'microphone')
        % Exit microphone   
        if is_tag(line,'/MICROPHONE') 
            state = '';
        % Name tag and file path
        elseif is_tag(line,'mic_name')  
               mic.name = get_tagvalue(line);
               mic.file = regexprep(file_path,'\.txt$','.wav');
        % Room tag
        elseif is_tag(line,'mic_room')  
               mic.room = get_tagvalue(line);
        % Position tag     
        elseif is_tag(line,'mic_pos')   
               fetch   = regexp(line ,'\s*<mic_pos>x=([0-9\.]+); y=([0-9\.]+); z=([0-9\.]+); \w*</mic_pos>\s*','tokens','once');
               mic.pos = [str2num(fetch{1}) str2num(fetch{2}) str2num(fetch{3})]; 
        % Unknown tag
        else
            error('Error while parsing %s in line %d, unknown MICROPHONE tag %s',...
                  meta_data_path,n_line,line)
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

% Append background
sources = append_background(sources,globals);

a=0;

%
% SUBFUNCTIONS
% 

function found = is_tag(string, tags)

% Ensure is a cell even if only one element
if ~iscell(tags)
    tags={tags};
end
found = 0;
for i=1:length(tags)
    % Either tag or tag value /tag allowed
    if regexp(string,['\s*<' tags{i}  '>[^<]*</' tags{i} '>\s*'...
                      '|<' tags{i}   '>'])
        found = 1;
    end
end


function [key, value] = get_tag(string)

if ~regexp(string,['\s*<[^>]*>[^<]*</[^>]*>\s*'])
    error('%s does not seem to be a tag with value', string)
end

%
cosa  = regexp(string,['\s*<([^>]*)>([^<]*)</[^>]*>\s*'],'tokens','once');
key   = cosa{1};
value = cosa{2};

function value = get_tagvalue(string)

if ~regexp(string,['\s*<[^>]*>[^<]*</[^>]*>\s*'])
    error('%s does not seem to be a tag with value', string)
end

%
cosa  = regexp(string,['\s*<([^>]*)>([^<]*)</[^>]*>\s*'],'tokens','once');
value = cosa{2};

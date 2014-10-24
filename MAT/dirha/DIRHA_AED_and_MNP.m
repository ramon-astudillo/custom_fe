% or_ref_mics = DIRHA_AED_and_MNP(config)
%
% Reads DIRHA configuration file and returns selected channels and VAD
% segments
%
% For this simulation and each command, get the reference microphones in
% the room where each command was produced. Return data in the form of each
% microphone audio file, index to oracle command position and index to
% previous acoustic context
% Get simulation name
%
% Ramón F. Astudillo

function or_ref_mics = DIRHA_AED_and_MNP(config)

% All DIRHA microphones in the house                                           
all_mics.('BEDROOM')    = { 'Wall/B1R.wav' 'Wall/B3L.wav' 'Wall/B1L.wav' ...   
                          'Wall/B2R.wav' 'Wall/B2C.wav' 'Wall/B2L.wav' ...    
                           'Wall/B3R.wav' };                                   
all_mics.('LIVINGROOM') = {'Array/LA3.wav' 'Array/LA4.wav' 'Array/LA6.wav' ... 
                           'Array/LA1.wav' 'Array/LA2.wav' 'Array/LA5.wav' ...  
                           'Wall/L1L.wav' 'Wall/L3R.wav' 'Wall/L2L.wav' ...     
                          'Wall/L1C.wav' 'Wall/L1R.wav' 'Wall/L3L.wav' ...     
                          'Wall/L4R.wav'  'Wall/L4L.wav' 'Wall/L2R.wav'};      
all_mics.('KITCHEN')    = {'Array/KA4.wav' 'Array/KA5.wav' 'Array/KA1.wav' ... 
                          'Array/KA3.wav' 'Array/KA6.wav' 'Array/KA2.wav' ...  
                          'Wall/K2L.wav' 'Wall/K1R.wav' 'Wall/K2R.wav' ...     
                          'Wall/K3L.wav' 'Wall/K3R.wav' 'Wall/K3C.wav' ...     
                          'Wall/K1L.wav'};                                     
all_mics.('BATHROOM')   = {'Wall/R1R.wav' 'Wall/R1L.wav' 'Wall/R1C.wav'};      
all_mics.('CORRIDOR')   = {'Wall/C1R.wav' 'Wall/C1L.wav'};       


% Determine frequency of input data if not provided
if config.in_fs == -1
    [dum,dum,config.in_fs] = readaudio(config.source_file,...
                                       config.byteorder, ...
                                       config.in_fs,config.fs);
end
% Determine if downsample needed
if config.fs < config.in_fs
    downsample = config.fs/config.in_fs;
else
    downsample = 0;
end

% Get the path identifying the simulation
sim_path    = regexp(config.source_file, ...
                     '(.*)/Signals/Mixed_Sources/.*', 'tokens', 'once');
sim_path    = sim_path{1};
                 
%
% MICROPHONE SELECTION
%

% Note that since there is a microphone selection decision per speech
% event, this also implies ideal segmentation. 
                 
% Identify speech events in the room by reading any mic
[dum, srcs] = readmetadata(config.source_file);
events      = fieldnames(srcs);
sp_events   = events(~cellfun(@isempty,regexp(events,'sp_.*')));
or_ms = cell(length(sp_events),1);

% Loop over the speech events
for c=1:length(sp_events)
    
    % ORACLE CLOSEST MIC TO THE EVENT IN THE ROOM
    if strcmp(config.mic_sel,'OracleMic')
        or_ms{c} = oracle_closest_mic(srcs.(sp_events{c}), downsample, sim_path, all_mics);
        
    % ORACLE ALL MICROPHONES IN THE ROOM ALIGNED
    elseif strcmp(config.mic_sel,'OracleAlign')
        or_ms{c} = oracle_aligned_mics(srcs.(sp_events{c}), downsample, sim_path, all_mics);
        
    % ORACLE REFERENCE MIC IN THE ROOM
    elseif strcmp(config.mic_sel,'OracleRoom')
        or_ms{c} = oracle_room_ref_mic(srcs.(sp_events{c}), downsample, sim_path);
    
    % Add here your own microphone selection strategy    
    elseif strcmp(config.mic_sel,'OracleRoom_EV')  
        or_ms{c} = EV_mic(srcs.(sp_events{c}), downsample, sim_path, all_mics, config, config.mic_sel);
        
    elseif strcmp(config.mic_sel,'EVmic')  
        or_ms{c} = EV_mic(srcs.(sp_events{c}), downsample, sim_path, all_mics, config, config.mic_sel);

    % GIVEN MICROPHONE    
    else
        % Read Oracle info for this mic
        [mic_tmp, srcs_tmp, globals_tmp] =...
            readmetadata(config.source_file, downsample);
        % Store info
        mic_sig.mic    = mic_tmp;
        mic_sig.src    = srcs_tmp.(sp_events{c});
        mic_sig.glb    = globals_tmp;
        or_ms{c}       = mic_sig;
    end
end


%
% ACUSTIC EVENT DETECTION
%

% This will hold the final reference microphone info
or_ref_mics = cell(length(or_ms),1);

% Loose/Tight VAD boundaries
if strcmp(config.vad,'OracleTxt') || strcmp(config.vad,'OracleSeg')
    for c=1:length(or_ms)
        or_ref_mics{c} = oracle_vad(or_ms{c},config.vad);
    end
    
% Whole signal
else
   error('Unknown VAD method %s',config.vad)
end

%
% SUBFUNCTIONS
%

function mic_sig = oracle_closest_mic(sp_event, downsample, sim_path, all_mics)

% Get all microphones for this event
room_mics = all_mics.(upper(sp_event.room));

% Initial distance
min_dist = Inf;
for m=1:length(room_mics)

    % Read info for this mic
    room_name                        = sp_event.room;
    [mic_tmp, srcs_tmp, globals_tmp] = ...
        readmetadata([ sim_path '/Signals/Mixed_Sources/' room_name(1) ...
        lower(room_name(2:end)) '/' room_mics{m}], downsample);
  
    % If this has the closest distance, store it
    if srcs_tmp.(sp_event.name).dist_mic < min_dist
        mic_sig.mic    = mic_tmp;
        mic_sig.src    = srcs_tmp.(sp_event.name);
        mic_sig.glb    = globals_tmp;
    end
    
end


function mic_sig = oracle_aligned_mics(sp_event, downsample, sim_path, all_mics)

% Get all microphones for this event
room_mics = all_mics.(upper(sp_event.room));
mic_sig   = cell(length(room_mics),1);
for m=1:length(room_mics)
    % Read info for this mic
    room_name                        = sp_event.room;
    [mic_tmp, srcs_tmp, globals_tmp] = ...
        readmetadata([ sim_path '/Signals/Mixed_Sources/' room_name(1) ...
        lower(room_name(2:end)) '/' room_mics{m}], downsample);

    tmp.mic    = mic_tmp;
    tmp.src    = srcs_tmp.(sp_event.name);
    tmp.glb    = globals_tmp;
    mic_sig{m} = tmp;
end


function mic_sig = oracle_room_ref_mic(sp_event,downsample,sim_path)

if strcmpi(sp_event.room, 'BEDROOM')
    room_mic = 'Wall/B1L.wav';
elseif strcmpi(sp_event.room, 'LIVINGROOM')
    room_mic = 'Array/LA6.wav';
elseif strcmpi(sp_event.room, 'KITCHEN')
    room_mic = 'Array/KA3.wav';
elseif strcmpi(sp_event.room, 'BATHROOM')
    room_mic = 'Wall/R1R.wav';
elseif strcmpi(sp_event.room, 'CORRIDOR')
    room_mic = 'Wall/C1R.wav';
else
    error('Unknown room %s', sp_event.room)
end

% Read info for this mic
[mic_tmp, srcs_tmp, globals_tmp] = ...
    readmetadata([ sim_path '/Signals/Mixed_Sources/' sp_event.room(1) ...
    lower(sp_event.room(2:end)) '/' room_mic], downsample);

% Store info
mic_sig.mic    = mic_tmp;
mic_sig.src    = srcs_tmp.(sp_event.name);
mic_sig.glb    = globals_tmp;


function mic_sig = EV_mic(sp_event, downsample, sim_path, all_mics, config, OrLevel)

% Select from all microphones in the room were this event takes place
if strcmp(OrLevel,'OracleRoom_EV')
    
    room_mics = all_mics.(upper(sp_event.room));
    
    % Unormalized envelope variances
    V = zeros(config.numchans,length(room_mics));
    for m=1:length(room_mics)
        
        % Read info for this mic
        room_name                        = sp_event.room;
        [mic_tmp, srcs_tmp, globals_tmp] = ...
            readmetadata([ sim_path '/Signals/Mixed_Sources/' room_name(1) ...
            lower(room_name(2:end)) '/' room_mics{m}], downsample);
        
        % Get the same event on this mic
        tmp_event = srcs_tmp.(sp_event.name);
        
        % Compute Envelope variance
        x_t    = readaudio(mic_tmp.file,config.byteorder,config.in_fs,config.fs);
        V(:,m) = envelope_var(x_t(tmp_event.begin_sample:tmp_event.end_sample), config);
    end
    
    % Normalize by channel max
    nV = V./repmat(max(V,[],2),1,size(V,2));
    % Use mean per channel for decision
    [dum, I] = max(mean(nV,1));
    
    % Read info for this mic
    [mic_tmp, srcs_tmp, globals_tmp] = ...
        readmetadata([ sim_path '/Signals/Mixed_Sources/' sp_event.room(1) ...
        lower(sp_event.room(2:end)) '/' room_mics{I}], downsample);
    
    
% Select from all microphones in the house
else                                      
    % Unormalized envelope variances
    V = zeros(config.numchans,40);
    rooms = fieldnames(all_mics);
    d=1;
    room_mics = cell(40,1);
    for r=1:length(rooms)
        for m=1:length(all_mics.(rooms{r}))
            
            % Read info for this mic
            [mic_tmp, srcs_tmp, globals_tmp] = ...
                readmetadata([ sim_path '/Signals/Mixed_Sources/' rooms{r}(1) ...
                lower(rooms{r}(2:end)) '/' all_mics.(rooms{r}){m}], downsample);
            
            % Get the same event on this mic
            tmp_event = srcs_tmp.(sp_event.name); 
            
            % Compute Envelope variance
            x_t    = readaudio(mic_tmp.file,config.byteorder,config.in_fs,config.fs);
            V(:,d) = envelope_var(x_t(tmp_event.begin_sample:tmp_event.end_sample), config);
            room_mics{d} = [ sim_path '/Signals/Mixed_Sources/' rooms{r}(1) ...
                             lower(rooms{r}(2:end)) '/' all_mics.(rooms{r}){m}];
            d=d+1;
        end
    end
    
    % Normalize by channel max
    nV = V./repmat(max(V,[],2),1,size(V,2));
    % Use mean per channel for decision
    [dum, I] = max(mean(nV,1));
    
    % Read info for this mic
    [mic_tmp, srcs_tmp, globals_tmp] = readmetadata(room_mics{I}, downsample);

end



% Store info
mic_sig.mic    = mic_tmp;
mic_sig.src    = srcs_tmp.(sp_event.name);
mic_sig.glb    = globals_tmp;


function or_ref_mics = oracle_vad(or_ms,vad)

% Aligned microphones case
if iscell(or_ms)
    or_ref_mics    = cell(4,1);
    or_ref_mics{1} = cell(length(or_ms),1);
    or_ref_mics{2} = cell(length(or_ms),1);
    or_ref_mics{3} = cell(length(or_ms),1);
    or_ref_mics{4} = cell(length(or_ms),1);
    for m=1:length(or_ms)
        % Store in simple format
        if strcmp(vad,'OracleTxt')
            or_ref_mics{1}{m} = or_ms{m}.mic.file;
            or_ref_mics{2}{m} = or_ms{m}.src.txt;
            or_ref_mics{3}{m} = or_ms{m}.src.bg_txt;
            or_ref_mics{4}{m} = 1;
        else
            or_ref_mics{1}{m} = or_ms{m}.mic.file;
            or_ref_mics{2}{m} = or_ms{m}.src.seg;
            or_ref_mics{3}{m} = or_ms{m}.src.bg_seg;
            or_ref_mics{4}{m} = 1;
        end
    end
% Single microphone case
else
    if strcmp(vad,'OracleTxt')
        or_ref_mics          = {or_ms.mic.file or_ms.src.txt ...
                                or_ms.src.bg_txt 1};
    else
        or_ref_mics          = {or_ms.mic.file or_ms.src.seg ...
                                or_ms.src.bg_seg 1};
    end    
end
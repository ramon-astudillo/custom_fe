% function or_ref_mics = OracleVADPosRoom_Align(sim_path, seg)
%
% Given the path of a DIRHA simulation, returns all microphones in
% the room where each speech event took place along with oracle VAD and 
% oracle room information. Due to the oracle VAD all events are 
% prefectly aligned and can be fed to a delay and sum module
%
% Input: sim_path      Path to a DIRHA-type simulation e.g. 
%
%                      /somepath/grid_dirha/dev1/sim1/ 
%
% Input: seg      = 1  If one, tight VAD  boundaries are used. Loose VAD used
%                      otherwise.  
%
% Output: or_ref_mics  Three level Cell. First level contains the speech
%                      events in the simulation. Second level contains 
%                      event information and third is each microphone in
%                      the room e.g.
%                    
%                      {
%                       {  % event
%                        {microphone_wav1, ..., microphone_wavN} ...
%                        {speech_index1,   ..., speech_indexN} ...
%                        {backg_index1,    ..., backg_index2} ...
%                        {room1,           ..., room2}
%                       } 
%                      {
%
% where the information is
% 
% microphone_wav       path of the chosen microphone (see clst_mic)
%
% speech_index         index in samples of the event within the microphone
%
% backg_index          index in samples of the preceeding background context
%
% Ramón F. Astudillo 


function or_ref_mics = OracleVADPosRoom_Align(sim_path, seg)

if nargin < 2
    seg     = 1;
end

% Get ground truth of microphone position in room
all_mics = { 'Bedroom/Wall/B1R.wav' 'Bedroom/Wall/B3L.wav' ...
             'Bedroom/Wall/B1L.wav' 'Bedroom/Wall/B2R.wav' ...
             'Bedroom/Wall/B2C.wav' 'Bedroom/Wall/B2L.wav' ...
             'Bedroom/Wall/B3R.wav' 'Livingroom/Array/LA3.wav' ...
             'Livingroom/Array/LA4.wav' 'Livingroom/Array/LA6.wav' ...
             'Livingroom/Array/LA1.wav' 'Livingroom/Array/LA2.wav' ...
             'Livingroom/Array/LA5.wav' 'Livingroom/Wall/L1L.wav' ...
             'Livingroom/Wall/L3R.wav' 'Livingroom/Wall/L2L.wav' ...
             'Livingroom/Wall/L1C.wav' 'Livingroom/Wall/L1R.wav' ...
             'Livingroom/Wall/L3L.wav' 'Livingroom/Wall/L4R.wav' ...
             'Livingroom/Wall/L4L.wav' 'Livingroom/Wall/L2R.wav' ...
             'Kitchen/Array/KA4.wav' 'Kitchen/Array/KA5.wav' ...
             'Kitchen/Array/KA1.wav' 'Kitchen/Array/KA3.wav' ...
             'Kitchen/Array/KA6.wav' 'Kitchen/Array/KA2.wav' ...
             'Kitchen/Wall/K2L.wav' 'Kitchen/Wall/K1R.wav' ...
             'Kitchen/Wall/K2R.wav' 'Kitchen/Wall/K3L.wav' ...
             'Kitchen/Wall/K3R.wav' 'Kitchen/Wall/K3C.wav' ...
             'Kitchen/Wall/K1L.wav' 'Bathroom/Wall/R1R.wav' ...
             'Bathroom/Wall/R1L.wav' 'Bathroom/Wall/R1C.wav' ...
             'Corridor/Wall/C1R.wav' 'Corridor/Wall/C1L.wav' };

% Get number of events from first mic and initialize 
sp_idx = readmetadata([ sim_path '/Signals/Mixed_Sources/' all_mics{1} ], seg);
for c = 1:length(sp_idx)
    or_ref_mics{c} = {};
    dist{c}    = {};  
end

% For each mic, check each speech event. Align and collect speech envents
% belonging to the room where they are produced.
for m=1:length(all_mics)

    % Current microphone
    source_file = [ sim_path '/Signals/Mixed_Sources/' all_mics{m} ];
    
    % Return oracle speech segmentation for each speech event in this 
    % microphone. Indicate whether each event is produced in the room of the
    % microphone and the distance of the source to the microphone in this case.
    [sp_idx, bg_idx, in_room, room, dist_mic] = readmetadata(source_file, seg);

    % Process each speech event in the mic, if it is in room, collect it
    for c = 1:length(sp_idx)
        if in_room(c)
            
            % Initialize the aligned microphone cell
            if isempty(or_ref_mics{c})
                or_ref_mics{c} = {{source_file}, {sp_idx{c}}, {bg_idx{c}}, {room{c}}};      
                dist{c}    = {dist_mic{c}};
                
            % Add to the aligned microphone cell    
            else
                or_ref_mics{c}{1}{end+1} = source_file;
                or_ref_mics{c}{2}{end+1} = sp_idx{c};
                or_ref_mics{c}{3}{end+1} = bg_idx{c};
                or_ref_mics{c}{4}{end+1} = room{c};
                dist{c}{end+1}       = dist_mic{c};
            end
        end
    end 
end
% Sort the commands (use the first of the aligned channels)
beg = [];
for c=1:length(or_ref_mics)
    beg(end+1) = or_ref_mics{c}{2}{1}(1);
end
[dum,I] = sort(beg);
or_ref_mics = {or_ref_mics{I}};
dist    = {dist{I}}; 

% function or_ref_mics = get_oracle_ref_mic(sim_path, clst_mic, seg)
%
% Given the path of a DIRHA simulation, returns oracle microphones,
% oracle VAD and oracle room information.
%
% Input: sim_path      Path to a DIRHA-type simulation e.g. 
%
%                      /somepath/grid_dirha/dev1/sim1/ 
%
% Input: clst_mic = 0  If one, closest mic to each speech event chosen.
%                      Otherwise the reference microphone in the room
%                      were the event took place is chosen.
%
% Input: seg      = 1  If one, tight VAD  boundaries are used. Loose VAD used
%                      otherwise.  
%
% Output: or_ref_mics  Two level Cell. First level contains the speech
%                      events in the simulation. Second level contains 
%                      following event info:
%
%                      {microphone_wav speech_index backg_index room} 
%
% microphone_wav       path of the chosen microphone (see clst_mic)
%
% speech_index         index in samples of the event within the microphone
%
% backg_index          index in samples of the preceeding background context
%
% Ramón F. Astudillo 

function or_ref_mics = get_oracle_ref_mic(sim_path, clst_mic, seg)

% Default is room oracle microphone
if nargin < 2
    clst_mic = 0;
end

% Default is tight VAD boundaries
if nargin < 3
    seg  = 1;
end

% All DIRHA microphones in the house
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
         
% INITIALIZE
or_ref_mics = {};
% In the case of closest mic we need to initialize all distances to -Inf
if clst_mic
    sp_idx = readmetadata([ sim_path '/Signals/Mixed_Sources/' all_mics{1} ], seg);
    for c = 1:length(sp_idx)
        or_ref_mics{c} = {};
        min_dist{c}    = Inf;
    end
end

% For all microphones in the house and each speech event, assign the event to
% either the central microphone of the room were it took place or the
% closest microphone in that room (clst_mic = 1)
for m=1:length(all_mics)
    
    % Current microphone file
    source_file = [ sim_path '/Signals/Mixed_Sources/' all_mics{m} ];
    
    % Current mic name
    this_mic = regexp(all_mics{m},'.*/([^/]*)\.wav','tokens','once');
    
    % Return oracle speech segmentation for each speech event in this 
    % microphone. Indicate whether each event is produced in the room of the
    % microphone and the distance of the source to the microphone in this case.
    [sp_idx, bg_idx, in_room, room, dist_mic] = readmetadata(source_file, seg);
    
    % For each speech event registered in the microphone taking place in the 
    % room where the mic is, select either closest or reference microphone.
    for c = 1:length(sp_idx)
        if in_room(c)
            
            % Oracle Closest mic
            % If the microphone is closer to the source than the one
            % stored, keep the new one            
            if clst_mic
                if dist_mic{c} < min_dist{c}
                    or_ref_mics{c} = {source_file, sp_idx{c}, bg_idx{c}, room{c}};
                    min_dist{c}    = dist_mic{c};
                end 
                
            % Oracle Room mic  
            % If this microphone is a reference microphone keep it
            else

                if strcmpi(this_mic, 'B1L')
                    or_ref_mics{end+1} = {source_file, sp_idx{c}, bg_idx{c}, room{c}};
                elseif strcmpi(this_mic, 'LA6')
                    or_ref_mics{end+1} = {source_file, sp_idx{c}, bg_idx{c}, room{c}};
                elseif strcmpi(this_mic, 'KA3')
                    or_ref_mics{end+1} = {source_file, sp_idx{c}, bg_idx{c}, room{c}};
                elseif strcmpi(this_mic, 'R1R')
                    or_ref_mics{end+1} = {source_file, sp_idx{c}, bg_idx{c}, room{c}};
                elseif strcmpi(this_mic, 'C1R')
                    or_ref_mics{end+1} = {source_file, sp_idx{c}, bg_idx{c}, room{c}};
                end
            end
        end
    end 
end
% Finally, it might be the case that the commands are not ordered in time.
% We need to sort them
beg = [];
for c=1:length(or_ref_mics)
    beg(end+1) = or_ref_mics{c}{2}(1);
end
[dum,I]     = sort(beg);
or_ref_mics = {or_ref_mics{I}};

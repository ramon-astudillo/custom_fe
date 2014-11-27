% function event = MNP_from_MLF(config)
%
% Cases:
%
% mlf_vad - MLF with *only one* regexp matching the source_file 
% 
% {{source_file sp_start sp_end bg_start bg_end room} ... }
% 
% DIRHA specific
%
% mlf_mic_sel  - MLF with *maximum one* microphone per event 
%
% {{mic_path sp_start sp_end bg_start bg_end} ... }
%
% mlf_mic_align - MLF with more than one microphone pr event. Events must thus
% be named differently!
%
% {{{mic_path1 sp_start sp_end bg_start bg_end}
%  {mic_path1 sp_start sp_end bg_start bg_end} ... } ... }
%

function sp_events = MNP_from_MLF(source_file, fs, trans, sel_type)

% A cell of events will be store here
sp_events = {};

% MLF_VAD CASE
if strcmp(sel_type, 'vad')
    % Look for a transcription for the source, error is none or more than one found
    idx = get_mlf_trans_idx(source_file, trans); 
    if isempty(idx)
        error('No transcription found for %s in MLF',source_file)
    elseif length(idx) > 1
        error('More than one transcription found for %s in MLF',source_file)
    end
    % Store each word in this transcription as a different speech event
    % TODO: allow here to give also info over other events different from 
    % speech
    t_prev = 1;
    for j=1:length(trans(idx).word)
        % Determine preceeding background if applies. Ignore segments smaller
        % than 100ms
        if (trans(idx).word(j).beg - 1 - t_prev)*1e-7 < 0.1 
            bg_init = t_ini*1e-7*fs;  
            bg_end  = (trans(idx).word(j).beg -1)*1e-7*fs;
            t_prev  = trans(idx).word(j).ende+1;
        else
            bg_init = []; 
            bg_end  = [];
        end
        %  Store file name indices for speech and backgrond and room 
        sp_init = ceil(trans(idx).word(j).beg*1e-7*fs);
        sp_end  = floor(trans(idx).word(j).ende*1e-7*fs);
        sp_events{end+1} = {source_file ...
                            sp_init:sp_end ...
                            bg_init:bg_end}; 
    end
    
    % Sort by event starting time
    st = [];
    for i=1:length(sp_events)
        st(i) = sp_events{i}{2}(1);
    end
    [st, I]   = sort(st);
    sp_events = {sp_events{I}};
    
% MLF_MIC_VAD CASE
elseif strcmp(sel_type,'mic_sel') 

    % Look for a transcription for the source, error if none or more than one found
    [root, lang, sets, sim] = get_dirha_path(source_file);
    
    idx = [];
    for i=1:length(trans)
        % Exclude filetype, replace HTK regexp by Matlab regexp
        [root2, lang2, sets2, sim2] = get_dirha_path(trans(i).name);
        if strcmp(lang, lang2) & strcmp(sets, sets2) & strcmp(sim, sim2)
            idx(end+1) = i;
        end
    end
    
    if isempty(idx)
        error('No transcription(s) found for %s in MLF',source_file)
    end
    % Store each word in this transcription as a different speech event
    % TODO: allow here to give also info oveBr other events different from 
    % speech
    t_prev = 1;
    for i = idx
        % Get room device and mic name from selected mic
        [dum, dum, dum, dum, broom, bdevice, bmic] = get_dirha_path(trans(i).name);                            
        if strcmp(lang,'grid')
            lang = [lang '_dirha'];
        end
        best_mic = [root '/' lang '/' sets '/sim' sim '/Signals/Mixed_Sources/' broom '/' bdevice '/' bmic '.wav'];
        
        % Loop over events in mic and add them with the time boundaries
        for j=1:length(trans(i).word)
            % Determine preceeding background if applies. Ignore segments smaller
            % than 100ms
            if (trans(i).word(j).beg - 1 - t_prev)*1e-7 > 0.1
                bg_init = ceil(t_prev*1e-7*fs);
                bg_end  = floor((trans(i).word(j).beg -1)*1e-7*fs);
                t_prev  = trans(i).word(j).ende+1;
            else
                bg_init = [];
                bg_end  = [];
            end
            %  Store file name indices for speech and backgrond and room
            sp_init          = ceil(trans(i).word(j).beg*1e-7*fs);
            sp_end           = floor(trans(i).word(j).ende*1e-7*fs);
            sp_events{end+1} = {best_mic, sp_init:sp_end, ...
                                bg_init:bg_end};
        end
    end
    
    
    % Sort by event starting time
    st = [];
    for i=1:length(sp_events)
        st(i) = sp_events{i}{2}(1);
    end
    [st, I]   = sort(st);
    sp_events = {sp_events{I}};


% MLF_MIC_ALIGN CASE
elseif strcmp(sel_type,'align') 
 
    % Get language, set and sim  
    [root, lang, sets, sim] = get_dirha_path(source_file);
    
    % Loop over transcriptions
    event_lst    = {};   % This will work as an ordered dict to index events
    min_ev_dur   = [];
    found        = 0;
    t_prev       = 1;
    for i=1:length(trans)
        
        % Skip all transcriptions that do not have same lang, set and sim
        [root2, lang2, sets2, sim2] = get_dirha_path(trans(i).name);
        if ~(strcmp(lang, lang2) & strcmp(sets, sets2) & strcmp(sim, sim2))
            continue            
        end
        found = 1;

        % Construct current mic path from source and transcription
        [dum, dum, dum, dum, broom, bdevice, bmic] = get_dirha_path(trans(i).name);                            
        if strcmp(lang,'grid')
            dbname = [lang '_dirha'];
        end
        curr_mic = [root '/' dbname '/' sets '/sim' sim '/Signals/Mixed_Sources/' broom '/' bdevice '/' bmic '.wav'];
        
        % Loop over events in current mic and add them with the time boundaries
        for j=1:length(trans(i).word)
            
            % Name of this event
            sp_name = trans(i).word(j).name;
            
            % Determine preceeding background if applies. Ignore segments smaller
            % than 100ms
            if (trans(i).word(j).beg - 1 - t_prev)*1e-7 > 0.1
                bg_init = ceil(t_prev*1e-7*fs);
                bg_end  = floor((trans(i).word(j).beg -1)*1e-7*fs);
                t_prev  = trans(i).word(j).ende+1;
            else
                bg_init = [];
                bg_end  = [];
            end 
            %  Store file name indices for speech and backgrond and room
            sp_init = ceil(trans(i).word(j).beg*1e-7*fs);
            sp_end  = floor(trans(i).word(j).ende*1e-7*fs);
            
            % If the event was already seen append the new mic to the
            % coresponding slot. Also keep track of the earliest event
            % start
            if any(strcmp(sp_name, event_lst))
                ev_idx = find(strcmp(sp_name, event_lst));
                sp_events{ev_idx}{end+1} = {curr_mic, sp_init:sp_end, ...
                                            bg_init:bg_end};                                  
                if sp_init <  min_ev_dur(ev_idx)                       
                    min_ev_dur(ev_idx) = sp_init;  
                end
            % Otherwise add a new slot    
            else
                sp_events{end+1} = {{curr_mic, sp_init:sp_end, ...
                                     bg_init:bg_end}};  
                event_lst{end+1}  = sp_name;                                    
                min_ev_dur(end+1) = sp_init;
            end 
        end  
    end
    if ~found
        error('No transcription(s) found for %s in MLF',source_file)
    end
    
    % Sort by earliest microphone to see each event
    [dum, I]  = sort(min_ev_dur);
    sp_events = {sp_events{I}};
    
else
    error(['MNP_from_MLF either MLF_VAD, MLF_MIC_SEL or MLF_MIC_ALIGN to be' ...
           ' defined in config'])
end
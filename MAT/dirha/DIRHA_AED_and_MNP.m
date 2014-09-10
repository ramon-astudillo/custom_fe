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

% ORACLE MICROPHONE SELECTION
% Note that Oracle mic selection is per speech event. This implies that we
% need a VAD before microphone selection.
if ~isempty(config.mic_sel)

    % Get the path identifying the simulation 
    sim_path    = regexp(config.source_file, ...
        '(.*)/Signals/Mixed_Sources/.*', 'tokens', 'once');
    
    % ORACLE ROOM: Central microphone of the room were speech event takes
    % place chosen
    if strcmp(config.mic_sel,'OracleRoom') 

        % Loose Oracle VAD
        if strcmp(config.vad, 'OracleTxt')
            or_ref_mics = get_oracle_ref_mic(sim_path{1},0,0);
            
        % Tight Oracle VAD    
        else
            or_ref_mics = get_oracle_ref_mic(sim_path{1},0,1);
        end
    
    % ORACLE MIC: Microphone closest to each speech event chosen
    elseif strcmp(config.mic_sel,'OracleMic')
        
        % Loose Oracle VAD
        if strcmp(config.vad, 'OracleTxt')
            or_ref_mics = get_oracle_ref_mic(sim_path{1},1,0);
            
        % Tight Oracle VAD    
        else
            or_ref_mics = get_oracle_ref_mic(sim_path{1},1,1);
        end
     
    % ORACLE ALIGN: All micropohones in the room were each event takes
    % place, aligned
    elseif strcmp(config.mic_sel,'OracleAlign')
        
        % Loose Oracle VAD
        if strcmp(config.vad, 'OracleTxt')
            or_ref_mics = OracleVADPosRoom_Align(sim_path{1},0);
            
            % Tight Oracle VAD
        else
            or_ref_mics = OracleVADPosRoom_Align(sim_path{1},1);
        end
  
    else
        error('Unknown mic_sel method %s', config.mic_sel)
    end

% ORACLE VAD ON GIVEN MICROPHONE
else
    if ~isempty(config.vad)
        
        % Tight Oracle VAD
        if strcmp(config.vad,'Oracle')
            [sp_idx, bg_idx] = readmetadata(config.source_file);
            or_ref_mics = {};
            for c = 1:length(sp_idx)
                or_ref_mics{end+1} = {config.source_file, sp_idx{c}, bg_idx{c}, 1};
            end
            
        % Loose Oracle VAD
        elseif strcmp(config.vad, 'OracleTxt')
            [sp_idx, bg_idx] = readmetadata(config.source_file, 0);
            or_ref_mics = {};
            for c = 1:length(sp_idx)
                or_ref_mics{end+1} = {config.source_file, sp_idx{c}, bg_idx{c}, 1};
            end
            
        % MLF VAD for current mic    
        elseif regexp(config.vad,'.*\.mlf')
            % Find the propper mlf for this set
            set = regexp(config.source_file, ...
            'grid_dirha/(.*)/sim\d*/Signals/Mixed_Sources/.*', 'tokens', 'once');
            config.vad = strrep(config.vad,'*', set);
            % Extract VAD from it
            [sp_idx,bg_idx] = get_vad_idx_from_mlf(config.vad{1},...
                config.target_file,config.fs);
            or_ref_mics = {};
            for c = 1:length(sp_idx)
                or_ref_mics{end+1} = {config.source_file, sp_idx{c}, bg_idx{c}, 1};
            end
            
%             % TODO: Check MLF actually from channel given
%             [sp_idx,bg_idx] = get_vad_idx_from_mlf(config.vad,...
%                 config.target_file,config.fs);
%             or_ref_mics = {};
%             for c = 1:length(sp_idx)
%                 or_ref_mics{end+1} = {config.source_file, sp_idx{c}, bg_idx{c}, 1};
%             end
            
        else
            error('Unknown VAD method %s', config.vad)
        end
        
    % NO VAD NO MIC SELECTION
    else    
        error('MMSEMFCC does needs always a VAD')
        %or_ref_mics = {{config.source_file 1:length(y_t) [] 1}};
    end
end

% Special: It is assumed that the oracles are given fot the in_fs of the
% corpus, not the work_fs of the features we sue. These can be different as
% e.g. in the DIRHA_simII corpus
% Get im_fs fromn the first file or the corpus
% For Aligned Microphones
if iscell(or_ref_mics{1}{1})
    [dum,dum,in_fs] = readaudio(or_ref_mics{1}{1}{1},config.byteorder, ...
        config.in_fs,config.fs);
    if config.fs < in_fs
        % Loop over speech events
        for i=1:length(or_ref_mics)
            % Loop over aligned microphones
            for m=1:length(or_ref_mics{i}{1})
                % Downsample boundaries for speech
                init_t = ceil(or_ref_mics{i}{2}{m}(1)*config.fs/in_fs);
                end_t  = floor(or_ref_mics{i}{2}{m}(end)*config.fs/in_fs);
                or_ref_mics{i}{2}{m} = init_t:end_t;
                % Downsample boundaries for background
                init_t = ceil(or_ref_mics{i}{3}{m}(1)*config.fs/in_fs);
                end_t  = floor(or_ref_mics{i}{3}{m}(end)*config.fs/in_fs);
                or_ref_mics{i}{3}{m} = init_t:end_t;
            end
        end
    end
% For best microphone
else
    [dum,dum,in_fs] = readaudio(or_ref_mics{1}{1},config.byteorder, ...
        config.in_fs,config.fs);
    if config.fs < in_fs
        for i=1:length(or_ref_mics)
            % Downsample boundaries for speech
            init_t = ceil(or_ref_mics{i}{2}(1)*config.fs/in_fs);
            end_t  = floor(or_ref_mics{i}{2}(end)*config.fs/in_fs);
            or_ref_mics{i}{2} = init_t:end_t;
            % Downsample boundaries for background
            init_t = ceil(or_ref_mics{i}{3}(1)*config.fs/in_fs);
            end_t  = floor(or_ref_mics{i}{3}(end)*config.fs/in_fs);
            or_ref_mics{i}{3} = init_t:end_t;
        end
    end
end

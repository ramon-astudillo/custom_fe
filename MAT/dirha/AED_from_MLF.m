function mic  = AED_from_MLF(config)

% Determine frequency of input data if not provided
if config.in_fs == -1
    [dum,dum,config.in_fs] = readaudio(config.source_file,...
                                       config.byteorder, ...
                                       config.in_fs, config.fs);
end
% Determine if downsample needed
if config.fs < config.in_fs
    downsample = config.fs/config.in_fs;
else
    downsample = 0;
end

% Read mlf and look for a transcription for our file
trans      = readmlf(config.vad);
found = 0;
for i=1:length(trans)     
     % Transform regexp into conventional one and try to match
     path_regxp = strrep(trans(i).name, '*', '.*');
     path_regxp = strrep(path_regxp, '.lab', '.wav');
     if regexp(config.source_file,['.*' path_regxp])
         word_trans = trans(i).word;
         found = 1;
         break
     end
end
if ~found
    error('Did not find a AED for %s in %s',config.source_file,config.vad)    
end

% Extract VAD from it
%mic     = cell(length(word_trans),1);
mic     = {};
prev_ed = 1;
for c = 1:length(word_trans)
    % Speech indices
    if downsample
        % from htk units to seconds, the to samples at in_fs and
        % downsampling
        sst = max(ceil(word_trans(c).beg*1e-7*config.in_fs*downsample), 1);
        sed = floor(word_trans(c).ende*1e-7*config.in_fs*downsample);
    else
        % from htk units to seconds, the to samples at in_fs and
        % downsampling
        sst = ceil(word_trans(c).beg*1e-7*config.in_fs);
        sed = floor(word_trans(c).ende*1e-7*config.in_fs);
    end

    % Skip segments that are too short
    if (sed-sst)/config.fs < 0.030
        continue
    end
    
    % Background indices
    if (sst-prev_ed)/config.fs > 0.030
       mic{end+1} = {config.source_file, sst:sed, prev_ed:(sst-1)};
    else    
       mic{end+1} = {config.source_file, sst:sed, []};
    end
    prev_ed = sed+1;
end

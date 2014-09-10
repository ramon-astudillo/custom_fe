function HTK_config = complete_defaults(HTK_config, HTK_supp, Extra_supp)

    % CHECK IF ANY NON SUPPORTED PARAMETER PRESENT
    fn = fieldnames(HTK_config);
    for i=1:length(fn)
        if ~isfield(HTK_supp, fn{i}) && ~isfield(Extra_supp, fn{i})
            error('Unknown HTK_config field %s', fn{i})
        end
    end

    % SAMPLING FREQUENCY EITHER IN HTK OR NORMAL FORMAT 
    if isfield(HTK_config, 'sourcerate')
        HTK_config.fs = floor(1e7/HTK_config.sourcerate);
    elseif ~isfield(HTK_config, 'fs')
        error('You need either to specifiy SOURCERATE or fs')
    end

    % WINDOWSIZE AND SHIFT EITHER IN HTK OR NORMAL FORMAT
    if (isfield(HTK_config, 'targetrate') && isfield(HTK_config, 'windowsize'))
        HTK_config.shift      = fix(HTK_config.fs*HTK_config.targetrate*1e-7);
        HTK_config.windowsize = fix(HTK_config.fs*HTK_config.windowsize*1e-7);
        HTK_config.nfft       = 2^nextpow2(HTK_config.windowsize); 

    elseif ~((isfield(HTK_config, 'shift')) && (isfield(HTK_config, 'windowsize')))
        error(['Either targetrate and windowsize in HTK units or'...
               'shift and windowsize in samples need to be defined'])
    elseif ~isfield(HTK_config, 'nfft')
        HTK_config.nfft = 2^nextpow2(HTK_config.windowsize);
    end

    % For compatibility with old versions
    HTK_config.overlap    = HTK_config.windowsize - HTK_config.shift;
    HTK_config.noverlap   = HTK_config.windowsize - HTK_config.shift;

    % FOR THE REST IF DEFAULTS EXISTS USE IT, OTHERWISE RISE ERROR 
    fn = fieldnames(HTK_supp);
    for i=1:length(fn)
        if ~isfield(HTK_config,fn{i})
            if isnan(HTK_supp.(fn{i}))
                error('You have to provide a value for HTK_config field %s', fn{i})
            else
                HTK_config.(fn{i}) = HTK_supp.(fn{i});
            end
        end
    end
    fn = fieldnames(Extra_supp);
    for i=1:length(fn)
        if ~isfield(HTK_config,fn{i})
            if isnan(Extra_supp.(fn{i}))
                error('You have to provide a value for HTK_config field %s', fn{i})
            else
                HTK_config.(fn{i}) = Extra_supp.(fn{i});
            end
        end
    end
    % DERIVED OBLIGATORY VALUES
    HTK_config.tc = targetkind2num(HTK_config.targetkind); 
    HTK_config.fp = HTK_config.shift/HTK_config.fs; 
% function x = feature_extraction(y_t, config)
%
% This an example function for signal processing + feature extraction 
%
% Input:  y_t       [T, C] matrix of C channels containing time domain signals
%                   of T samples
%                   
%                   IMPORTANT NOTE: When DIRHA meta-data used, the signal used
%                   in the end might NOT be y_t e.g. by channel selection               
%         
% Input:  config    Structure containing information pre-computed at 
%                   init_feature_extraction_config.m and previous stages
% 
% Output: Features  [I, L] matrix containing features. I is the number of 
%                   features and L the number of analysis frames. 
%
%
% DIRHA-CORPORA: 
%
% This function supports DIRHA-corpora meta-information to use oracles. This 
% is activated if config fields 'mic_sel' and 'vad' are set, see code below
% DIRHA CORPORA ACOUSTIC EVENT DETECTION AND MICROPHONE NETWORK PROCESSING
%
%
% OBSERVATION UNCERTAINTY:
%
% This function supports observation uncertainty. If config field UNC_PROP is 
% set to one (-up flag used in MCopy), the function  appends feature variances
% to attain a [2*I,L] vector. A suitable method to compute the variances has to
%  be provided as e.g. SPLICE. In this case STFT-UP is used
%
%
% Ramon F. Astudillo Feb2014

function [x, vad] = feature_extraction(y_t, config)

%
% DIRHA CORPORA ACOUSTIC EVENT DETECTION AND MICROPHONE NETWORK PROCESSING 
%

if ~isempty(config.mic_sel) || ~isempty(config.vad)
    
    % Check we are using a known DIRHA corpus
    if isempty(regexp(config.source_file, ...
        '(.*)/Signals/Mixed_Sources/.*', 'tokens', 'once'))
        error(['You set MIC_SEL or VAD fields in config to values that' ...
               ' imply DIRHA-corpus specific actions.\nThe path you gave'...
               '\n    (%s)\ndoes not seem to be a known DIRHA corpus though'],...
               config.source_file)
    end
    
    % Use DIRHA ORACLES to obtain a cell of different speech events
    or_ref_mics = DIRHA_AED_and_MNP(config);
else
    % If no DIRHA meta-data used, assume only one speech event with current 
    % file and no background. This is *not* a good option for DIRHA data as 
    % utterances are very long. This option is left here for compatibility 
    % with shorter tasks.    
    if ~isempty(config.noise_estimation)
        % If we use speech enhancement we will nedd a small initialization 
        % segment at least. We pick here 20ms. 
        t_init      = 0.02*config.fs;
        or_ref_mics = {{config.source_file t_init+1:length(y_t) 1:t_init 1}};
    else
        % Drop allways the first 500ms for coherence with IMCRA
        t_init      = 0.02*config.fs;
 %       or_ref_mics = {{config.source_file t_init+1:length(y_t) 1:t_init 1}};       
        or_ref_mics = {{config.source_file 1:length(y_t) [] 1}};
    end
end

%
% PROCESSING FOR EACH SPEECH EVENT
%

if config.separate_events 
    x   = cell(length(or_ref_mics),1);
    vad = cell(length(or_ref_mics),1);
else
    % Initialize a matrix to store the features to maximum size. This will be cut
    %  to l_max later
    L        = fix((length(y_t)-config.windowsize) ...
        /(config.windowsize - config.overlap)) + 1;
    mu_x     = zeros(3*(config.numceps+1),L);
    Sigma_x  = zeros(3*(config.numceps+1),L);
    l_max    = 1;
    vad      = {}; % wont be used
end

% Initialize noise
Lambda_D = 1e-6*ones(config.nfft/2+1,1);

% Loop over each speech event
for i=1:length(or_ref_mics)
   
    %
    % BEAMFORMING AND VAD 
    %
    
    if strcmp(config.mic_sel,'OracleAlign')
        % Apply delay and sum to the aligned speech and precceding
        % background events
        [y_t, d_t] = delay_and_sum(or_ref_mics{i},config.byteorder,...
                                   config.in_fs,config.fs);
    else
        % Microphone audio and indices for command and preceeding background
        z_t = readaudio(or_ref_mics{i}{1},config.byteorder,...
                        config.in_fs,config.fs);
        % For non-DIRHA data it might be the case that we have multiple
        % channels. In this case add them
        if size(z_t,2) > 1
            z_t = sum(z_t,2);
        end      
        y_t = z_t(or_ref_mics{i}{2});
        d_t = z_t(or_ref_mics{i}{3});
    end

    % Rules for exact results on the DIRHA-GRID baseline
    % When using external MLF-based VAD, skip speech segments shorter than 3000
    if ~isempty(regexp(config.vad,'.*\.mlf', 'once')) && length(y_t) < 3000
        continue
    end
    % Skip background according to different critearia for each approach 
    est_backgr = 1;
    if strcmp(config.mic_sel, 'OracleAlign') 
        if length(or_ref_mics{i}{3}{end}) <= 3000
            est_backgr = 0;
        end
    elseif (strcmp(config.mic_sel, 'OracleRoom') || ~isempty(config.vad))
        if isempty(d_t)
            est_backgr = 0;
        end
    elseif length(d_t) <= 3000;
        est_backgr = 0;
    end

    %
    % NOISE ESTIMATION
    %
    
    if ~isempty(config.noise_estimation) 
        
        % Simple enhancement with Lambda_D and decision directed a priori SNR
        % estimation. Provides the posterior of the Wiener filter
        if strcmp(config.noise_estimation, 'VAD')
            
            % ESTIMATE OF NOISE VARIANCE FROM BACKGROUND
            if est_backgr 
                Lambda_D = noise_estimation(d_t,config);
            end
           
            % SPEECH ENHANCEMENT 
            % It resturns the Wiener filter and minimum MSE in STFT domain
            [hat_X_W, MSE] = speech_enhancement(y_t,Lambda_D,config);
                       
        % IMCRA noise estimation    
        elseif strcmp(config.noise_estimation, 'IMCRA')
            
            % UPDATE IMCRA's MINIMA TRACKING FROM BACKGROUND
            if est_backgr 
                config = IMCRA_noise_estimation(d_t,config); 
            end
           
            % SPEECH ENHANCEMENT
            % Use IMCRA for noise estimation.
            [hat_X_W, MSE] = IMCRA_speech_enhancement(y_t,Lambda_D,config);
        
        % Unknown method    
        else            
            error('Unknown noise_estimation method %s', config.noise_estimation)
        end
    end

    %
    % PROPAGATION THROUGH ISTFT+STFT
    %
    
    if config.iup
        % Posterior propagation through ISTFT
        hat_X_W = stft_HTK(istft_HTK(hat_X_W,config),config);
        MSE     = istft_stft_HTK_up(MSE,config,config);
    end

    %
    % ENHANCEMENT AND FEATURE EXTRACTION
    %
    
    if ~isempty(config.enhancement)
        
        if strcmp(config.enhancement,'LSA') 
        
            % SPECTRAL DOMAIN ENHANCEMENT
            % SNR of Wiener posterior (for the noise Fourier coeff.)
            nu        = (abs(hat_X_W).^2)./MSE;
            % MMSE-LSA estimate
            hat_X_LSA = abs(hat_X_W).*exp(.5*expint(nu));
            
            % FEATURE EXTRACTION
            % Transform through the MFCCs
            [m_x,S_x] = mfcc_up(hat_X_LSA, zeros(size(hat_X_LSA)), config);
            % Append deltas, accelerations
            [m_x,S_x] = append_deltas_up(m_x,S_x,config.targetkind,...
                                         config.deltawindow,...
                                         config.accwindow,...
                                         config.simplediffs);
            % cms *only* in this segment
            [m_x,S_x] = cms_up(m_x,S_x);

        elseif strcmp(config.enhancement,'MFCC') 

            % MFCC DOMAIN ENHANCEMENT
            % Transform Wiener posterior through the MFCCs
            [m_x,S_x] = mfcc_up(hat_X_W, MSE, config);
            % Append deltas, accelerations
            [m_x,S_x] = append_deltas_up(m_x,S_x,config.targetkind,...
                                         config.deltawindow,...
                                         config.accwindow,...
                                         config.simplediffs);
            % cms *only* in this segment
            [m_x,S_x] = cms_up(m_x,S_x);
        else
            error('Unknown enhancement method %s', config.enhancement)
        end
    
    else
        
        % STFT
        Y         = stft_HTK(y_t,config);
        
        % NORMAL MFCCs NO ENHANCEMENT
        [m_x,S_x] = mfcc_up(Y,zeros(size(Y)),config);
        % Append deltas, accelerations
        [m_x,S_x] = append_deltas_up(m_x,S_x,config.targetkind, ...
                                             config.deltawindow, ...
                                             config.accwindow, ...
                                             config.simplediffs);
        % cms
        [m_x,S_x] = cms_up(m_x,S_x);        
    end
    
    % Store features either by concatenation or in a cell along with vad
    % info
    if config.separate_events
        
        % Identify the room
        if iscell(or_ref_mics{1}{1})
            fetch=regexp(or_ref_mics{i}{1}{1}, ...
                         '.*/Signals/Mixed_Sources/(.*)','tokens','once');
        else
            fetch=regexp(or_ref_mics{i}{1}, ...
                         '.*/Signals/Mixed_Sources/(.*)','tokens','once'); 
        end
        roommic = fetch{1};
        
        % Return only mean or also variance
        if config.unc_prop
            x{i} = [m_x; S_x];
        else
            x{i} = m_x;
        end
        % If multiple mics per event processed, use boundaries of the
        % first
        if iscell(or_ref_mics{1}{1})
            vad{i} = sprintf('%s %d %d\n',roommic,...
                                  or_ref_mics{i}{2}{1}(1),...
                                  or_ref_mics{i}{2}{1}(end));
        else
           vad{i} = sprintf('%s %d %d\n',roommic,...
                                  or_ref_mics{i}{2}(1),...
                                  or_ref_mics{i}{2}(end));
        end

    else    
        L2                            = size(m_x,2);
        mu_x(:,l_max:l_max+(L2-1))    = m_x;
        Sigma_x(:,l_max:l_max+(L2-1)) = S_x;
        l_max                         = l_max + L2;       
    end
end

if ~config.separate_events
    % Drop unused array space
    mu_x(:,l_max:end) = [];
    Sigma_x(:,l_max:end) = [];
    
    % Check for no speech detected at all, pass the whole utterance instead
    if l_max < 50
        % STFT
        Y = stft_HTK(y_t,config);
        % Propagate Wiener filter posterior through the MFCCs
        [m_x,S_x] = mfcc_up(Y,zeros(size(Y)),config);
        % Append deltas, accelerations
        [m_x,S_x] = append_deltas_up(m_x,S_x,config.targetkind,...
            config.deltawindow,...
            config.accwindow,...
            config.simplediffs);
        % cms *only* in this segment
        [mu_x,Sigma_x] = cms_up(m_x,S_x);
        %error('No speech was detected in %s!',config.source_file)
    end
    
    % Return only mean or also variance
    if config.unc_prop
        x = [mu_x; Sigma_x];
    else
        x = mu_x;
    end
end

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


% Get a set of (suposedly) aligned microphones for each speech event
if ~isempty(regexp(config.mlf_mic_align,'.*\.mlf')) 
    sel_type = 'align';
% Get a microphone for each speech event
elseif ~isempty(regexp(config.mlf_mic_sel,'.*\.mlf')) 
    sel_type = 'mic_sel';
                         
% Get VAD for the currently given microphone
elseif ~isempty(regexp(config.mlf_vad,'.*\.mlf'))
    sel_type = 'vad';     
else
    sel_type = '';
end
      
%
% CUSTOM MICROPHONE SELECTION OR AED FROM AN MLF 
%    

if ~isempty(sel_type)     
    sp_events = MNP_from_MLF(config.source_file, config.fs, config.mlf_trans, ...
                             sel_type);                        
%
% NO MICROPHONE SELECTION OR AED
%   
    
%elseif ~isempty(config.noise_estimation)
else
    % If no DIRHA meta-data used, assume only one speech event with current 
    % file and no background. This is *not* a good option for DIRHA data as 
    % utterances are very long. This option is left here for compatibility 
    % with shorter tasks.    
    % If we use speech enhancement we will nedd a small initialization 
    % segment at least. We pick here 20ms. 
    t_init    = 0.02*config.fs;
    sp_events = {{config.source_file t_init+1:length(y_t) 1:t_init}};
end

%
% PROCESSING FOR EACH SPEECH EVENT
%

n_events = length(sp_events);

% This will store each event bu separate
x   = cell(n_events,1);
vad = cell(n_events,1);
% Initialize noise
Lambda_D = 1e-6*ones(config.nfft/2+1,1);

% Loop over each speech event
for i=1:length(sp_events)
   
    %
    % BEAMFORMING OR VAD 
    %
    
    if isfield(config,'mlf_mic_align') & ~isempty(config.mlf_mic_align)
        % Apply delay and sum to the aligned speech and precceding
        % background events
        [y_t, d_t] = delay_and_sum(sp_events{i},config.byteorder,...
                                   config.in_fs,config.fs);
    else
        % Microphone audio and indices for command and preceeding background
        z_t = readaudio(sp_events{i}{1},config.byteorder,...
                        config.in_fs,config.fs);
        % For non-DIRHA data it might be the case that we have multiple
        % channels. In this case add them
        if size(z_t,2) > 1
            z_t = sum(z_t,2);
        end      
        y_t = z_t(sp_events{i}{2});
        d_t = z_t(sp_events{i}{3});
    end

    %
    % ENHANCEMENT 
    %
    
    if ~isempty(config.enhancement)
    
        %
        % NOISE ESTIMATION
        %
        
        % Simple enhancement with Lambda_D and decision directed a priori SNR
        % estimation. Provides the posterior of the Wiener filter
        if strcmp(config.noise_estimation, 'VAD')
            
            % ESTIMATE OF NOISE VARIANCE FROM BACKGROUND
            Lambda_D = noise_estimation(d_t,config);
  
            % SPEECH ENHANCEMENT 
            % It resturns the Wiener filter and minimum MSE in STFT domain
            [hat_X_W, MSE] = speech_enhancement(y_t,Lambda_D,config);
                       
        % IMCRA noise estimation    
        elseif strcmp(config.noise_estimation, 'IMCRA')
            
            % UPDATE IMCRA's MINIMA TRACKING FROM BACKGROUND
            config = IMCRA_noise_estimation(d_t,config); 

           
            % SPEECH ENHANCEMENT
            % Use IMCRA for noise estimation.
            [hat_X_W, MSE] = IMCRA_speech_enhancement(y_t,Lambda_D,config);
        
        % Unknown method    
        else            
            error('Unknown noise_estimation method %s', config.noise_estimation)
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
        % ENHANCEMENT
        %
 
        if strcmp(config.enhancement,'LSA') 
        
            % SPECTRAL DOMAIN ENHANCEMENT
            % SNR of Wiener posterior (for the noise Fourier coeff.)
            nu        = (abs(hat_X_W).^2)./MSE;
            % MMSE-LSA estimate
            hat_X_LSA = abs(hat_X_W).*exp(.5*expint(nu));

            % PASS LSA AS POINT ESTIMATE
            hat_X = hat_X_LSA;
            MSE   = zeros(size(hat_X));   

          elseif strcmp(config.enhancement,'MFCC') 

            % PASS WIENER POSTERIOR
            hat_X = hat_X_W;
            MSE   = MSE;       % Just to left this clearer  

        else
            error('Unknown enhancement method %s', config.enhancement)
        end
    
    else
        % PASS NOISY SPECTRUM
        hat_X = stft_HTK(y_t,config);
        MSE   = zeros(size(hat_X));         
    end


    %
    % FEATURE EXTRACTION
    %

    % MFCC DOMAIN ENHANCEMENT
    % Transform Wiener posterior through the MFCCs
    [m_x,S_x] = mfcc_up(hat_X, MSE, config);
    % Append deltas, accelerations
    [m_x,S_x] = append_deltas_up(m_x,S_x,config.targetkind,...
                                 config.deltawindow,...
                                 config.accwindow,...
                                 config.simplediffs);
    % cms *only* in this segment
    [m_x,S_x] = cms_up(m_x,S_x);

    %    
    % STORE FEATURES IN DIFFERENTE CELLS ALONG WITH TRANSCRIPTION INFO 
    %

    % Return also variance if uncertainty porpagation used
    if config.unc_prop
        x{i} = [m_x; S_x];
    else
        x{i} = m_x;
    end
 
    % Return microphone and boundaruies for each speech event. 
    % If the dirha align version used, return a regexp matching mics in the room.
    if isfield(config,'mlf_mic_align') & ~isempty(config.mlf_mic_align)
        % Parse this dirha mic
        [root, lang, set, sim, room, device, mic, typ, fs] ...
            = get_dirha_path(sp_events{i}{1}{1});
        % replace device and mic name by asterisk
        mic_regexp = strrep(sp_events{i}{1}{1},['/' device '/'],'/*/');    
        mic_regexp = strrep(mic_regexp,['/' mic '.'],'/*.');    
        vad{i} = sprintf('"%s"\n%d %d speech.%d\n.\n', sp_events{i}{1}{1},...
                         round(sp_events{i}{1}{2}(1)/config.fs*1e7),...
                         round(sp_events{i}{1}{2}(end)/config.fs*1e7),i);

    else
        vad{i} = sprintf('"%s"\n%d %d speech.%d\n.\n', sp_events{i}{1},...
                         round(sp_events{i}{2}(1)/config.fs*1e7),...
                         round(sp_events{i}{2}(end)/config.fs*1e7),i);
    end
end

% CONCATENATE EVERYTHING INTO A SINGLE FILE IF SOLICITED
if ~config.separate_events
    error('To be implemented')
end

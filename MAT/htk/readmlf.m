% function trans = readmlf(mlf_file,varargin)
%
% Reads HTK's transcriptions in MLF format. 
%
% Input:  mlf_file  string with the path to the MLF file
%
% Output: trans      structure array with as many elements as utterances and 
%                    fields:
%
%                    name: path of utterance
%                    word: structure with fields:                       
%                         name: Word
%                         beg:  time at which word starts
%                         ende: time at which word ends
%                         logp: log-likelihood 
%
% Default Options 
%
% T            = 0   Trace levels.
%
% pre_read     = 0   Read once the mlf_file to know the length and the 
%                    inform of progress with waitbar   
%                              
% Ramon F. Astudillo 

function trans = readmlf(mlf_file,varargin)

% DEFAULTS
T            = 0;  
pre_read     = 0;  

overload_defaults(varargin);

% OPEN FILE FOR READING
fid = fopen(mlf_file,'r');
if fid == -1
    error('File % s could not be opened or found',mlf_file);
end

% IF PRE-READ SOLICITED
if pre_read
   % Count only the number of lines
   n_line_tot = 0;
   line = fgetl(fid); 
   fprintf('Reading mlf_file lines...\n')
   while line ~= -1 
       n_line_tot = n_line_tot +1;
       line=fgetl(fid);  
   end
   h = waitbar(0,sprintf('Reading a mlf_file with % d lines',n_line_tot));
   fclose(fid);
   fid=fopen(mlf_file,'r');
end

line    = fgetl(fid);  
n_words = 0;
n_utt   = 0;
trans   = [];
n_line  = 0;

while line ~= -1 
    n_line =  n_line + 1;
    % If comment sign '#' found remove all content after it              
    com_idx = strfind(line,'#');               
    if ~isempty(com_idx)                   
        line = line(1:com_idx-1);              
    end
    % LOOK FOR CHARACTER INDICATING FILEPATH
    com_idx=strfind(line,'"');
    % IF TWO FILE PATH CHARACTERS FOUND
    if length(com_idx) > 1
        % Increase number of utterances counter
        n_utt=n_utt+1;
        % Set number of words of this sentence to zero
        n_words=0;
        % We should have two ", read the content between them as utterance
        % name
        trans(n_utt).name=line(com_idx(1)+1:com_idx(2)-1);
    % ELSE IF LINE CONTAINS ONLY A POINT AT THE BIGINNING OF THE LINE
    elseif regexp(line,'^\s*\.')
        % Indicates end of transcription for this sentence
        % Mark this utterance transcription as completed (useful for 
        % recovering aborted labeling procedures)
        trans(n_utt).completed = 1;
    % ELSE IF IT LINE IS NOT EMPTY
    elseif ~isempty(line)
        % Assume it is a trancription, try to read all components
        items=regexp(line, ...
                     '(\d+\s)?(\d+\s)?([^\s]*\.?)(\s+-?\d*\.?\d*)?',...
                     'tokens','once');
        if ~isempty(items)
            n_words=n_words+1;
            % Optional word start in seconds
            if ~isempty(items{1})
                trans(n_utt).word(n_words).beg = str2double(items{1});
            end
            % Optional word en in seconds
            if ~isempty(items{2})
                trans(n_utt).word(n_words).ende = str2double(items{2});
            end
            % Word name
            trans(n_utt).word(n_words).name = items{3};
            % Optional loglikelihood
            if ~isempty(items{4}) 
                trans(n_utt).word(n_words).logp = ...
                str2double(strtrim(items{4})); 
            end
        end
    end
    
    % GET NEXT LINE            
    line = fgetl(fid);           
    % Empty lines should be treated as comments          
    if isempty(line) 
        line='#'; 
    end    
    % INFO IF PRE_READ
    if pre_read & ~mod(n_line,100)
         waitbar(n_line/n_line_tot,h,sprintf('Processing % d/%d lines',...
                 n_line,n_line_tot));
    end

end
fclose(fid);
% INFO IF PRE_READ
if pre_read
   close(h);
end

% INFO
if T>=1; 
    fprintf('% d transcriptions read from %s\n',n_utt,mlf_file);
end

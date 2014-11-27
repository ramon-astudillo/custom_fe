% function idx = get_mlf_trans_idx(file_path, mlf_trans)
%
% Find index (indices) of regexp(s) in mlf_trans of transcriptions matching
% file_path
%
% Input: file_path   string path of a file 
% Input: mlf_trans   struct read from readmlf 
%
% Output: Index of matching transcriptions in mlf_trans

function idx = get_mlf_trans_idx(file_path, mlf_trans)

% Exclude file type
[dirname, basename, type] = fileparts(file_path);
file_path = [dirname '/' basename];
% Loop over transcriptions
idx = [];
for i=1:length(mlf_trans) 
    % Exclude filetype, replace HTK regexp by Matlab regexp
    [dirname, basename, type] = fileparts(mlf_trans(i).name);
    pathreg = strrep([dirname '/' basename],'*','.*');
    if regexp(file_path, pathreg)
       idx(end+1) = i; 
    end
end

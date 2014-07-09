% function [file_list,file_list2] = readscp(scp_file,varargin)
%
% Reads HTK's list of files in SCP format (just a list). 
%
% Input:  scp_file   string with the path to the SCP file 
%
% Output: file_list   cell with each source path
%         file_list2  cell with each target path (see default options)
%
% T                = 0;    Trace options 
% comm             = '#';  Character used to denote beginning of comment 
% forHCopy         = 0;    Set to 1 to extract source and target path   
% file_list2       = {};   Second list of files for HCopy like scps  
% append_root_path = '';   Path to be appended at the beginning of the 
%                          paths to read 
%
% Ramon F. Astudillo 

function [file_list,file_list2] = readscp(scp_file,varargin)

% DEFAULTS
T                = 0;                        
comm             = '#';                 
forHCopy         = 0;               
file_list2       = {};            
append_root_path = '';      

overload_defaults(varargin);

% OPEN FILE FOR READING
fid = fopen(scp_file,'r');
if fid == -1
    error('File % s could not be opened or found',scp_file);
end

n_files   = 0;
file_list = {};
line      = fgetl(fid);
while line ~= -1
    % If comment sign '#' found remove all content after it              
    com_idx = strfind(line,comm);
    if ~isempty(com_idx) 
        line = line(1:com_idx-length(comm)); 
    end     
    % If its a path line process it and copy it into the list
    % This files not allways have type indication
    if ~isempty(line) 
        % If not an HCopy type of file (sorce target pairs) 
        if ~forHCopy
            n_files            = n_files+1;
            file_list{n_files} = strtrim(line);
        else
            % Scps for HCopy have two paths on one single line
            n_files               = n_files+1;
            [file_list{n_files},...
             file_list2{n_files}] = strtok(line);
            file_list{n_files}    = strtrim(file_list{n_files});
            file_list2{n_files}   = strtrim(file_list2{n_files});
        end
        % If path to be appended provided  
        if ~isempty(append_root_path)
            % if source file starts with '.'
            if strcmp(file_list{n_files}(1),'.')
                % Remove it
                file_list{n_files} =file_list{n_files}(2:end); 
            end
            
            % if target file starts with '.'
            if strcmp(file_list2{n_files}(1),'.')
                % Remove it
                file_list2{n_files} =file_list2{n_files}(2:end); 
            end
            
            % Add root path to the paths of source files
            file_list{n_files}  = [append_root_path file_list{n_files}];
            % If the were also target paths created
            if forHCopy
                % Add root path to the paths of target files
                file_list2{n_files} = ...
                                    [append_root_path file_list2{n_files}];
            end
        end
    end
    % Get nextline
    line=fgetl(fid);
end
fclose(fid);
if ~forHCopy 
    if T>0; 
       fprintf('%d files listed from %s\n',n_files,scp_file); 
    end
else
    if T>0; 
        fprintf(['%d files and their corresponding targets' ...
                 ' listed from %s\n'],n_files,scp_file); 
    end
end

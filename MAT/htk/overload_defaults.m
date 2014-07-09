% function [] = overload_defaults(name_val_pairs,allowed_names,T)
%
% Creates variables in the workspace from which we call this function. This
% provides matlab functions with a functionality similar to Pythons **kwargs
%
% Input:  name_val_pairs string of odd number of arguments containing 
%                        'variable_name' variable_value pairs.
%
% Input: allowed_names   cell of strings indicating variables than can be 
%                        overloaded. If not specified, all variables present
%                        in the caller workspace can be overloaded
%
% Example:
%
% If you have the function definition
%
%        function someout = foo(fix1,fix2,varargin)
%        
%        % Default values
%        var1 = 'blah';
%        var2 = 0; 
%        var3 = 'nopes';
%     
%        % Overloading here    
%        overload_defaults(varargin)
%
%        % Rest of code 
%        ...
%
% then the call
%
%       someout1 = foo(fix1,fix2,'var1','bleh','var2',Inf)
%
% will overide the values of the parameters specified to 'bleh' and Inf 
% respectively AFTER overload_defaults(varargin) is called.
%
% IMPORTANT: The only limitation are dependent definitions of the type
%
%   var1 = 'blah';
%   var2 =  [ var 'blih'];
%
% Here overloading var1 WILL NOT overload var2 because the variables are 
% overloaded AFTER all defaults are declared. Do NOT use dependent 
% definitions in the defaults when using overload_defaults 
%
% Ramon F. Astudillo

function [] = overload_defaults(name_val_pairs,allowed_names,T)

% ARGUMENT PROCESSING
if nargin < 3
    % Default is trace T=0 (No information printed to MATLAB)
    T=0;
end

% If allowed_names not specified, all variables in caller workspace are 
% allowed to be overloaded
if nargin < 2 || isempty(allowed_names)
    allowed_names=evalin('caller','who');
end

% CHECK FOR ODD NUMBER OF ARGUMENTS
if mod(length(name_val_pairs),2)
    error(['The number of arguments in name_val_pairs must be even ' ... 
           '(pairs of variable_name variable_value). See help' ...
           'overload_defaults'])
end

% QUICK EXIT
if isempty(name_val_pairs)
    return
end

% INFORM THE USER
if T>=1
    % GET CALLER NAME
    callers=dbstack;
    % INFORM
    fprintf(['overload_defaults: Overloading %s arguments at line %d' ...
             ' with\n'],upper(callers(2).name),callers(2).line);
    fprintf('\n')
end

% OVERLOAD EACH VARIABLE IN name_val_pairs
for i=1:2:length(name_val_pairs)
    % CHECK FOR FIRST ARGUMENT NOT BEING A STRING, AND PARAMETER BEING 
    % ALLOWED
    if ~ischar(name_val_pairs{i})
        error(['Parameters to be overloaded must be specified in the' ...
               ' form <variable name (string)> <variable value>'])
    elseif ~ismember(name_val_pairs{i},allowed_names)
                errormsg = sprintf(['%s not valid name_val_pairs arg' ...
                                    ' allowed:\n'],name_val_pairs{i});
        % Display list of allowed arguments
        for j=1:length(allowed_names)
            errormsg = [errormsg sprintf('\t%s\n',allowed_names{j})];
        end
        error(errormsg);
    else
        assignin('caller',name_val_pairs{i},name_val_pairs{i+1});
    end
end

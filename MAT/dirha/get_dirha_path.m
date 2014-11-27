function [root, lang, sets, sim, room, device, mic, typ, fs] = get_dirha_path(file_path)

% Strings defining the different possible dirha paths
% DIRHA-SIM
dirha_sim  = ['(.*)/*DIRHA_sim2/*([A-Z\*]+)/+([a-z0-9\*]+)/+[a-z\*]*/*' ...
              'sim([0-9]+)/+Signals/+Mixed_Sources/+([A-Za-z\*]+)/+' ...
              '([A-Za-z\*]+)/+([A-Z0-9\*]+)\.([^\.\*]*)$' ];
% GRID-DIRHA
dirha_grid = ['(.*)/*(grid)_dirha/*([a-z0-9\*]+)/+sim([0-9]*)/+Signals/+' ...
              'Mixed_Sources/+([A-Za-z\*]+)/+([A-Za-z\*]+)/+([A-Z0-9\*]+)' ...
              '\.([^\.\*]*)$' ];
% GRID-DIRHA features
%dirha_grid_mfc = [ './features/(DIRHA_sim2/ITA|DIRHA_sim2/PT' ...
%                   '|DIRHA_sim2/GR|DIRHA_sim2/DE|grid_dirha)/' ...
%                   '(dev1|test1|test2)/sim([0-9]*)/Signals/' ...
%                   'detection.mfc' ]

if regexp(file_path, dirha_sim)
    % DIRHA SIMULATED CORPUS
    fetch  = regexp(file_path, dirha_sim, 'tokens');
    root   = fetch{1}{1};
    lang   = fetch{1}{2};
    sets   = fetch{1}{3};
    sim    = fetch{1}{4};
    room   = fetch{1}{5};
    device = fetch{1}{6};
    mic    = fetch{1}{7};
    typ    = fetch{1}{8};
    fs     = 48000;
elseif regexp(file_path, dirha_grid)
    % DIRHA GRID CORPUS
    fetch  = regexp(file_path, dirha_grid, 'tokens');
    root   = fetch{1}{1};
    lang   = fetch{1}{2};
    sets   = fetch{1}{3};
    sim    = fetch{1}{4};
    room   = fetch{1}{5};
    device = fetch{1}{6};
    mic    = fetch{1}{7};
    typ    = fetch{1}{8};
    fs     = 16000;
else
    root   = [];
    lang   = [];
    sets   = [];
    sim    = [];
    room   = [];
    device = [];
    mic    = [];
    typ    = [];
    fs     = [];
end

% function sources = append_background(sources,globals,seg)
%
% For each speech event, it tries to find preceeding background were there
% is no speech (if exists). This can be used later to initialize
% enhancement algorithms
%


function sources = append_background(sources,globals)

sp_src_names = {};
for e=1:length(globals)
    % Look for speech events in this slot. 
    event_text = globals{e}{3};
    fetch      = ~cellfun(@isempty,regexp(event_text,'sp_.*'));
    % For each one found, check if previously processed. If not add it to
    % list and determine precceding background
    if any(fetch) 
        sp_ev = event_text(fetch);
        % Skip if the event is not in our sources
        for i=1:length(sp_ev)
            if ~any(ismember(sp_ev{i},sp_src_names))
                % Add to the list
                sp_src_names{end+1} = sp_ev{i};
                
                % Look back in all precceding slots, accumulate background
                % until speech found
                sources.(sp_ev{i}).bg_seg = [];
                sources.(sp_ev{i}).bg_txt = [];
                for e2 =e-1:-1:1
                    
                    % There is speech in previous slot
                    if any(~cellfun(@isempty,regexp(globals{e2}{3},'sp_.*')))
                        
                        % TODO: Some discrimination based on room can be done
                        % here. We could also check for tight bounds and get
                        % some extra bg from here
                        break
                        
                    else
                        sources.(sp_ev{i}).bg_seg = globals{e2}{1}:sources.(sp_ev{i}).seg(1);
                        sources.(sp_ev{i}).bg_txt = globals{e2}{1}:sources.(sp_ev{i}).txt(1);
                    end
                end
                
            end
        end
    end
end

a=0;
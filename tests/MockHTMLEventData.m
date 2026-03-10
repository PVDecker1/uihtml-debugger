classdef MockHTMLEventData < event.EventData
    properties
        HTMLEventName = 'ConsoleError'
        HTMLEventData
    end

    methods
        function obj = MockHTMLEventData(level, message, stack)
            obj.HTMLEventData = struct('level', level, 'message', message, 'stack', stack);
        end
    end
end

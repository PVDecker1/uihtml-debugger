classdef MockUihtmlComponent < handle
    events
        HTMLEventReceived
    end
    properties
        HTMLEventReceivedFcn
        HTMLSource = ''
    end
end

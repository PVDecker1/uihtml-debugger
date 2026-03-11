classdef MockUihtmlComponent < handle
    events
        HTMLEventReceived
    end
    properties
        HTMLEventReceivedFcn
        HTMLSource string = ""
    end
end

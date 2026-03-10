classdef ConsoleErrorRerouter < handle
    % ConsoleErrorRerouter Intercepts JavaScript console errors and routes them to the MATLAB Command Window.
    %
    %   obj = ConsoleErrorRerouter(uihtmlComp) creates a rerouter for the given
    %   uihtml component.

    properties
        % Toggles rerouting on/off without destroying the object. Default: true.
        Enabled (1,1) logical = true

        % Console levels to intercept. Default: ["error"]. Allowed: "error", "warn", "info", "log".
        ErrorLevels (1,:) string {mustBeMember(ErrorLevels, ["error", "warn", "info", "log"])} = ["error"]

        % Custom formatter f(level, message, stack) -> char. Default: built-in red-text formatter using fprintf.
        FormatFcn (1,1) function_handle = @ConsoleErrorRerouter.defaultFormatter
    end

    properties (SetAccess = private)
        % Last message received, for unit testing purposes.
        LastMessage char = ''
    end

    properties (Access = private)
        HtmlComponent
        EventListener
    end

    methods
        function obj = ConsoleErrorRerouter(uihtmlComp)
            % ConsoleErrorRerouter Constructor
            arguments
                uihtmlComp (1,1)
            end

            obj.HtmlComponent = uihtmlComp;

            % Add our listener using addlistener to avoid clobbering an existing HTMLEventReceivedFcn
            if isprop(uihtmlComp, 'HTMLEventReceived') || isprop(uihtmlComp, 'HTMLEventReceivedFcn')
                try
                    obj.EventListener = addlistener(uihtmlComp, 'HTMLEventReceived', @(src, event) obj.onHTMLEventReceived(src, event));
                catch
                    error('uihtmlRerouter:badArgument', 'Provided component does not support HTMLEventReceived event.');
                end
            else
                error('uihtmlRerouter:badArgument', 'Provided component must be a matlab.ui.control.HTML object.');
            end
        end

        function delete(obj)
            % delete Destructor
            if ~isempty(obj.EventListener) && isvalid(obj.EventListener)
                delete(obj.EventListener);
            end
        end
    end

    methods (Access = private)
        function onHTMLEventReceived(obj, ~, eventData)
            if ~obj.Enabled
                return;
            end

            % Ensure eventData has HTMLEventName property
            if ~isprop(eventData, 'HTMLEventName') || ~strcmp(eventData.HTMLEventName, 'ConsoleError')
                return;
            end

            % Extract payload
            payload = eventData.HTMLEventData;

            % Allow for struct or object representation of payload
            if isstruct(payload) || isobject(payload)
                % In newer MATLAB versions UIHTML payloads might be structs
                try
                    level = string(payload.level);
                    message = char(payload.message);
                    if isfield(payload, 'stack') || isprop(payload, 'stack')
                        stack = char(payload.stack);
                    else
                        stack = '';
                    end
                catch
                    return; % Not the expected format
                end
            else
                return; % Not the expected format
            end

            if ~ismember(level, obj.ErrorLevels)
                return;
            end

            obj.LastMessage = message;

            % Format and output
            formattedOutput = obj.FormatFcn(level, message, stack);
            if ~isempty(formattedOutput)
                if level == "error"
                    fprintf(2, '%s\n', formattedOutput);
                else
                    fprintf('%s\n', formattedOutput);
                end
            end
        end
    end

    methods (Static, Access = private)
        function out = defaultFormatter(level, message, stack)
            out = sprintf('Console %s: %s', upper(level), message);
            if ~isempty(stack)
                out = sprintf('%s\nStack Trace:\n%s', out, stack);
            end
        end
    end
end

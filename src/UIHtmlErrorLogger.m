classdef UIHtmlErrorLogger < handle
    % UIHtmlErrorLogger - Captures and displays console errors from uihtml components
    %
    % This class listens for HTMLEventReceived events from a uihtml component
    % and displays JavaScript console errors in the MATLAB command window.
    % The implementation follows MATLAB's recommended communication pattern
    % using sendEventToMATLAB from JavaScript to MATLAB.
    %
    % Usage:
    %   % Create uihtml component
    %   h = uihtml(parent);
    %   h.HTMLSource = 'your-file.html'; % Must include uihtml-error-rerouter.js
    %   
    %   % Attach error logger
    %   errorLogger = UIHtmlErrorLogger(h);
    %
    % The HTML file must include the uihtml-error-rerouter.js script which
    % uses sendEventToMATLAB to send console error messages to this class.
    
    properties (Access = private)
        UIHtmlComponent % The uihtml component to listen to
        EventListener   % Listener for HTMLEventReceived events
    end
    
    methods
        function obj = UIHtmlErrorLogger(htmlComponent)
            % Constructor - Creates error logger for specified uihtml component
            %
            % Parameters:
            %   htmlComponent - matlab.ui.control.HTML object
            
            if nargin < 1
                error('UIHtmlErrorLogger:MissingInput', ...
                    'UIHtmlErrorLogger requires a uihtml component as input.');
            end
            
            if ~isa(htmlComponent, 'matlab.ui.control.HTML')
                error('UIHtmlErrorLogger:InvalidInput', ...
                    'Input must be a uihtml component (matlab.ui.control.HTML).');
            end
            
            obj.UIHtmlComponent = htmlComponent;
            obj.setupListener();
            
            fprintf('UIHtmlErrorLogger initialized for uihtml component.\n');
            fprintf('Listening for console errors from HTML content...\n');
        end
        
        function delete(obj)
            % Destructor - Clean up event listener when object is destroyed
            
            if ~isempty(obj.EventListener) && isvalid(obj.EventListener)
                delete(obj.EventListener);
            end
            
            fprintf('UIHtmlErrorLogger stopped listening.\n');
        end
        
        function status = getStatus(obj)
            % Get current status of the error logger
            %
            % Returns:
            %   status - struct with listener and component status
            
            status = struct();
            status.isListening = ~isempty(obj.EventListener) && isvalid(obj.EventListener);
            status.componentValid = ~isempty(obj.UIHtmlComponent) && isvalid(obj.UIHtmlComponent);
            status.componentType = class(obj.UIHtmlComponent);
        end
    end
    
    methods (Access = private)
        function setupListener(obj)
            % Set up event listener for HTMLEventReceived events
            
            obj.EventListener = listener(obj.UIHtmlComponent, ...
                'HTMLEventReceived', ...
                @(src, event) obj.handleHtmlEvent(src, event));
        end
        
        function handleHtmlEvent(obj, ~, event)
            % Handle HTMLEventReceived events and process console errors
            %
            % Parameters:
            %   src - Event source (uihtml component)
            %   event - Event data containing JSON message from HTML
            
            try
                % Attempt to parse the JSON string from HTML
                eventData = jsondecode(event.Data);
                
                % Check if this is a console error event
                if obj.isConsoleErrorEvent(eventData)
                    obj.displayError(eventData);
                end
                
            catch ME
                % Handle cases where event.Data is not valid JSON
                warning('UIHtmlErrorLogger:EventParsingError', ...
                    'Could not parse HTMLEventReceived data: %s\nError: %s', ...
                    event.Data, ME.message);
            end
        end
        
        function isError = isConsoleErrorEvent(~, eventData)
            % Check if event data represents a console error
            %
            % Parameters:
            %   eventData - Parsed JSON data from HTML event
            %
            % Returns:
            %   isError - true if this is a console error event
            
            isError = isstruct(eventData) && ...
                      isfield(eventData, 'type') && ...
                      strcmp(eventData.type, 'consoleError') && ...
                      isfield(eventData, 'message');
        end
        
        function displayError(~, eventData)
            % Display console error in MATLAB command window
            %
            % Parameters:
            %   eventData - Parsed console error data
            
            % Extract timestamp if available
            timestamp = '';
            if isfield(eventData, 'timestamp')
                try
                    dt = datetime(eventData.timestamp, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
                    timestamp = sprintf('[%s] ', char(dt, 'HH:mm:ss'));
                catch
                    % Use timestamp as-is if parsing fails
                    timestamp = sprintf('[%s] ', eventData.timestamp);
                end
            end
            
            % Display error message in red text (stderr)
            fprintf(2, '%s%s\n', timestamp, eventData.message);
            
            % If additional error details are available, display them
            if isfield(eventData, 'error') && isstruct(eventData.error)
                errorDetails = eventData.error;
                if isfield(errorDetails, 'filename') && isfield(errorDetails, 'lineno')
                    fprintf(2, '  Source: %s (line %d)\n', ...
                        errorDetails.filename, errorDetails.lineno);
                end
            end
        end
    end
end
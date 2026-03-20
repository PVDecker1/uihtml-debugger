classdef ConsoleErrorRerouter < handle
    % ConsoleErrorRerouter Intercepts JavaScript console errors and routes them to the MATLAB Command Window.
    %
    %   obj = ConsoleErrorRerouter(uihtmlComp) creates a rerouter for the given
    %   uihtml component.

    properties
        % Toggles rerouting on/off without destroying the object. Default: true.
        Enabled (1,1) logical = true

        % Console levels to intercept. Default: ["error"].
        % Allowed values: "error", "warn", "info", "log", "debug".
        ErrorLevels (1,:) string {mustBeMember(ErrorLevels, ...
            ["error","warn","info","log","debug"])} = ["error"]

        % Custom format function.
        % Function signature: f(level, message, stack).
        % Default: built-in formatter.
        FormatFcn (1,1) function_handle = @ConsoleErrorRerouter.defaultFormatter
    end

    properties (SetAccess = private)
        % Last message received, for unit testing purposes.
        LastMessage string = ""
    end

    properties (Access = private)
        % Reference to the uihtml component.
        HtmlComponent
        % Internal listener handle for HTMLEventReceived.
        EventListener
        % Backup of the original HTMLSource.
        OriginalHTMLSource string = ""
        % Path to the temporary injected HTML file.
        TempHTMLPath string = ""
    end

    methods
        function obj = ConsoleErrorRerouter(uihtmlComp)
            % ConsoleErrorRerouter Constructor
            %
            %   obj = ConsoleErrorRerouter(uihtmlComp) attaches the rerouter to 
            %   the provided uihtml component.
            arguments
                uihtmlComp
            end

            if ~isprop(uihtmlComp, "HTMLSource") && ~isfield(uihtmlComp, "HTMLSource")
                error("ConsoleErrorRerouter:InvalidComponent", ...
                    "Provided component must have an HTMLSource property.");
            end

            obj.HtmlComponent = uihtmlComp;

            % Use addlistener to catch events. This doesn't clobber HTMLEventReceivedFcn.
            try
                obj.EventListener = listener(uihtmlComp, "HTMLEventReceived", ...
                        @(src, event) obj.onHTMLEventReceived(src, event));
            catch
                % For mocks that don't support listeners, we skip it.
            end

            % Handle shim delivery if HTMLSource is provided
            if strlength(string(uihtmlComp.HTMLSource)) > 0
                obj.injectShim();
            end
        end % Constructor

        function delete(obj)
            % delete Destructor
            %
            %   Cleans up temporary files.

            % Cleanup shim delivery
            obj.removeShim();
        end % function delete
    end % methods

    methods (Access = private)
        function injectShim(obj)
            % injectShim Injects the JavaScript shim into a temporary copy of the HTML.
            source = string(obj.HtmlComponent.HTMLSource);
            obj.OriginalHTMLSource = source;

            % If it's a URL, we cannot inject the shim by file modification.
            if startsWith(source, "http://") || startsWith(source, "https://")
                error("ConsoleErrorRerouter:UrlHTMLSource", ...
                    "URLs are not supported by ConsoleErrorRerouter");
            end

            % Read original HTML
            if isfile(source)
                htmlContent = fileread(source);
            else
                error("ConsoleErrorRerouter:InvalidHTMLSource", ...
                    "HTML source must be a file.");
            end

            % Prepare the shim script block
            % We wrap the existing setup function to capture the htmlComponent.
            dSelf = fileparts(mfilename("fullpath"));
            pShim = fullfile(dSelf,"Support","shim_lines.js");
            shimScript = fileread(pShim);

            % Insert just before </body> or at the end
            [startIdx, ~] = regexpi(htmlContent, "</body>");
            if ~isempty(startIdx)
                insertPos = startIdx(1);
                newHtml = [htmlContent(1:insertPos-1), newline, char(shimScript), ...
                    newline, htmlContent(insertPos:end)];
            else
                newHtml = [htmlContent, newline, char(shimScript)];
            end

            % Write injected HTML to a temporary file in the same directory
            [targetDir, name, ext] = fileparts(source);
            if strlength(targetDir) == 0
                targetDir = pwd;
            end
            [~,uuid] = fileparts(tempname);
            obj.TempHTMLPath = fullfile(targetDir, name + "_rerouter_" + uuid + ext);
            
            try
                writelines(newHtml,obj.TempHTMLPath);
            catch
                error("ConsoleErrorRerouter:TempWriteFailure", ...
                    "Filed to write temporary html file to:\n%s",obj.TempHTMLPath);
            end

            % Update the component's HTMLSource with the temporary file path.
            obj.HtmlComponent.HTMLSource = "";
            obj.HtmlComponent.HTMLSource = obj.TempHTMLPath;
        end % function injectShim

        function removeShim(obj)
            % removeShim Restores the original HTML and cleans up the temporary file.
            if isa(obj.HtmlComponent, "handle") && isvalid(obj.HtmlComponent) && ...
                    strlength(obj.OriginalHTMLSource) > 0
                try
                    obj.HtmlComponent.HTMLSource = obj.OriginalHTMLSource;
                catch
                    % Ignore restoration errors
                end
            end

            % Delete temporary HTML file
            if ~isempty(obj.TempHTMLPath) && isfile(obj.TempHTMLPath)
                delete(obj.TempHTMLPath);
                if isfile(obj.TempHTMLPath)
                    warning("ConsoleErrorRerouter:FailedCleanup", ...
                        "Failed to delete %s. Please check your file system", ...
                        obj.TempHTMLPath)
                end
            end
        end % function removeShim
    end % methods (Access = private)

    methods (Access = {?tConsoleErrorRerouter, ?ConsoleErrorRerouter})
        function onHTMLEventReceived(obj, ~, eventData)
            % onHTMLEventReceived Internal callback for uihtml events.
            if ~obj.Enabled
                return;
            end

            % Standard HTMLEventReceivedData properties: HTMLEventName and HTMLEventData
            eventName = string(eventData.HTMLEventName);
            payload = eventData.HTMLEventData;

            if ~matches(eventName,"ConsoleError")
                return;
            end

            % Extract console message data
            if isstruct(payload) || isobject(payload)
                if isfield(payload,"level")
                    level = string(payload.level);
                else
                    return
                end

                % Filter based on ErrorLevels
                if ~any(matches(level,obj.ErrorLevels))
                    return;
                end

                message = string(payload.message);
                if isfield(payload, "stack") || isprop(payload, "stack")
                    stack = string(payload.stack);
                else
                    stack = "";
                end
            else
                return;
            end

            obj.LastMessage = message;

            % Format and output
            obj.FormatFcn(level, message, stack);
        end % function onHTMLEventReceived
    end % methods (Access = private)

    methods (Static)
        function defaultFormatter(level, message, ~)
            % defaultFormatter Built-in formatter using fprintf and warning.
            if matches(level,"error")
                fprintf(2, "[JS error] %s\n", message);
            elseif matches(level,"warn")
                % Backtrace off to avoid confusing the user with internal Rerouter stack
                state = warning("off", "backtrace");
                warning("uihtmlRerouter:consoleWarn", "[JS warn] %s", message);
                warning(state);
            else
                fprintf(1, "[JS %s] %s\n", char(level), message);
            end
        end % function defaultFormatter
    end % methods (Static, Access = private)
end % classdef ConsoleErrorRerouter
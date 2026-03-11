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
        ErrorLevels (1,:) string = ["error"]

        % Custom formatter f(level, message, stack) -> void. Default: built-in formatter.
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
                uihtmlComp (1,1)
            end

            obj.HtmlComponent = uihtmlComp;

            % Use addlistener to catch events. This doesn't clobber HTMLEventReceivedFcn.
            try
                obj.EventListener = addlistener(uihtmlComp, "HTMLEventReceived", ...
                    @(src, event) obj.onHTMLEventReceived(src, event));
            catch
                % Fallback: Check if it's a real uihtml component
                if ~isprop(uihtmlComp, "HTMLEventReceivedFcn") && ...
                        ~isprop(uihtmlComp, "HTMLSource")
                    error("uihtmlRerouter:badArgument", ...
                        "Provided component must be a matlab.ui.control.HTML object.");
                end
            end

            % Handle shim delivery if HTMLSource is provided
            if isprop(uihtmlComp, "HTMLSource") && ~isempty(string(uihtmlComp.HTMLSource))
                obj.injectShim();
            end
        end

        function delete(obj)
            % delete Destructor
            %
            %   Cleans up listeners and temporary files.
            if ~isempty(obj.EventListener) && isvalid(obj.EventListener)
                delete(obj.EventListener);
            end

            % Cleanup shim delivery
            obj.removeShim();
        end
    end

    methods (Access = private)
        function injectShim(obj)
            % injectShim Injects the JavaScript shim into a temporary copy of the HTML.
            source = string(obj.HtmlComponent.HTMLSource);
            obj.OriginalHTMLSource = source;

            % If it's a URL, we cannot inject the shim by file modification.
            if startsWith(source, "http://") || startsWith(source, "https://")
                return;
            end

            % Read original HTML
            try
                fid = fopen(source, "r", "n", "utf-8");
                if fid == -1
                    return;
                end
                htmlContent = fread(fid, "*char")';
                fclose(fid);
            catch
                return;
            end

            % Prepare the shim script block
            % We wrap the existing setup function to capture the htmlComponent.
            shimScriptLines = [ ...
                "<script id=""console-rerouter-shim"">" ...
                "(function() {" ...
                "    var _userSetup = (typeof setup === 'function') ? setup : null;" ...
                "    setup = function(htmlComponent) {" ...
                "        var levels = ['error', 'warn', 'log', 'info', 'debug'];" ...
                "        levels.forEach(function(level) {" ...
                "            var _orig = console[level];" ...
                "            console[level] = function() {" ...
                "                var args = Array.prototype.slice.call(arguments);" ...
                "                var message = args.map(function(a) {" ...
                "                    if (a instanceof Error) return a.message;" ...
                "                    if (typeof a === 'object') { try { return JSON.stringify(a); } catch(e) { return String(a); } }" ...
                "                    return String(a);" ...
                "                }).join(' ');" ...
                "                var stack = (args[0] instanceof Error && args[0].stack) ? args[0].stack : '';" ...
                "                htmlComponent.sendEventToMATLAB('ConsoleError', { level: level, message: message, stack: stack });" ...
                "                if (typeof _orig === 'function') { _orig.apply(console, arguments); }" ...
                "            };" ...
                "        });" ...
                "        if (_userSetup) { _userSetup(htmlComponent); }" ...
                "    };" ...
                "})();" ...
                "</script>" ...
            ];
            shimScript = join(shimScriptLines, newline);

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
            if isempty(targetDir)
                targetDir = pwd;
            end
            obj.TempHTMLPath = fullfile(targetDir, name + "_rerouter_temp" + ext);
            
            try
                fid = fopen(obj.TempHTMLPath, "w", "n", "utf-8");
                if fid == -1
                    return;
                end
                fwrite(fid, newHtml, "char");
                fclose(fid);
            catch
                obj.TempHTMLPath = "";
                return;
            end

            % Update the component's HTMLSource with the temporary file path.
            obj.HtmlComponent.HTMLSource = obj.TempHTMLPath;
        end

        function removeShim(obj)
            % removeShim Restores the original HTML and cleans up the temporary file.
            try
                if isa(obj.HtmlComponent, "handle") && isvalid(obj.HtmlComponent) && ...
                        ~isempty(obj.OriginalHTMLSource)
                    obj.HtmlComponent.HTMLSource = obj.OriginalHTMLSource;
                end
            catch
            end

            % Delete temporary HTML file
            if ~isempty(obj.TempHTMLPath) && isfile(obj.TempHTMLPath)
                try
                    delete(obj.TempHTMLPath);
                catch
                end
            end
        end

        function onHTMLEventReceived(obj, ~, eventData)
            % onHTMLEventReceived Internal callback for uihtml events.
            if ~obj.Enabled
                return;
            end

            % Standard HTMLEventReceivedData properties: HTMLEventName and HTMLEventData
            try
                eventName = string(eventData.HTMLEventName);
                payload = eventData.HTMLEventData;
            catch
                % Fallback for cases where eventData might be structured differently
                try
                    eventName = string(eventData.Data.HTMLEventName);
                    payload = eventData.Data.HTMLEventData;
                catch
                    return;
                end
            end

            if eventName ~= "ConsoleError"
                return;
            end

            % Extract console message data
            if isstruct(payload) || isobject(payload)
                try
                    level = string(payload.level);
                    
                    % Filter based on ErrorLevels
                    if ~any(level == obj.ErrorLevels)
                        return;
                    end
                    
                    message = string(payload.message);
                    if isfield(payload, "stack") || isprop(payload, "stack")
                        stack = string(payload.stack);
                    else
                        stack = "";
                    end
                catch
                    return;
                end
            else
                return;
            end

            obj.LastMessage = message;

            % Format and output
            obj.FormatFcn(level, message, stack);
        end
    end

    methods (Static, Access = private)
        function defaultFormatter(level, message, ~)
            % defaultFormatter Built-in formatter using fprintf and warning.
            if level == "error"
                fprintf(2, "[JS error] %s\n", message);
            elseif level == "warn"
                % Backtrace off to avoid confusing the user with internal Rerouter stack
                state = warning("off", "backtrace");
                warning("uihtmlRerouter:consoleWarn", "[JS warn] %s", message);
                warning(state);
            else
                fprintf(1, "[JS %s] %s\n", char(level), message);
            end
        end
    end
end

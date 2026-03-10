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
        OriginalHTMLSource char = ''
        CopiedShimPath char = ''
        TempHTMLPath char = ''
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

            % Handle shim delivery if HTMLSource is provided
            if isprop(uihtmlComp, 'HTMLSource') && ~isempty(char(uihtmlComp.HTMLSource))
                obj.injectShim();
            end
        end

        function delete(obj)
            % delete Destructor
            if ~isempty(obj.EventListener) && isvalid(obj.EventListener)
                delete(obj.EventListener);
            end

            % Cleanup shim delivery
            obj.removeShim();
        end
    end

    methods (Access = private)
        function injectShim(obj)
            source = char(obj.HtmlComponent.HTMLSource);
            obj.OriginalHTMLSource = source;

            % If it's a URL, we cannot inject the shim by file copying.
            if startsWith(source, 'http://') || startsWith(source, 'https://')
                return;
            end

            % Get target directory and original filename
            [targetDir, name, ext] = fileparts(source);
            if isempty(targetDir)
                targetDir = pwd;
            end

            % Resolve path to consoleShim.js
            myDir = fileparts(mfilename('fullpath'));
            shimSrc = fullfile(myDir, 'js', 'consoleShim.js');

            if ~isfile(shimSrc)
                return;
            end

            % Copy shim to target directory
            obj.CopiedShimPath = fullfile(targetDir, 'consoleShim.js');
            try
                % Avoid copying over itself if already there
                if ~strcmp(shimSrc, obj.CopiedShimPath)
                    copyfile(shimSrc, obj.CopiedShimPath, 'f');
                end
            catch
                % Cannot copy, return early
                obj.CopiedShimPath = '';
                return;
            end

            % Read original HTML
            try
                fid = fopen(source, 'r', 'n', 'utf-8');
                if fid == -1
                    return;
                end
                htmlContent = fread(fid, '*char')';
                fclose(fid);
            catch
                return;
            end

            % Prepend script tag
            scriptTag = '<script src="consoleShim.js"></script>';

            % Try to find <head>
            [startIdx, endIdx] = regexpi(htmlContent, '<head[^>]*>');
            if ~isempty(endIdx)
                insertPos = endIdx(1);
                newHtml = [htmlContent(1:insertPos), newline, scriptTag, newline, htmlContent(insertPos+1:end)];
            else
                % Try to find <html>
                [startIdx, endIdx] = regexpi(htmlContent, '<html[^>]*>');
                if ~isempty(endIdx)
                    insertPos = endIdx(1);
                    newHtml = [htmlContent(1:insertPos), newline, '<head>', scriptTag, '</head>', newline, htmlContent(insertPos+1:end)];
                else
                    newHtml = [scriptTag, newline, htmlContent];
                end
            end

            % Write injected HTML to a temporary file in the same directory
            obj.TempHTMLPath = fullfile(targetDir, [name, '_rerouter_temp', ext]);
            try
                fid = fopen(obj.TempHTMLPath, 'w', 'n', 'utf-8');
                if fid == -1
                    return;
                end
                fwrite(fid, newHtml, 'char');
                fclose(fid);
            catch
                obj.TempHTMLPath = '';
                return;
            end

            % Update the component's HTMLSource with the temporary file path.
            obj.HtmlComponent.HTMLSource = obj.TempHTMLPath;
        end

        function removeShim(obj)
            % Restore original HTMLSource property
            if isvalid(obj.HtmlComponent) && ~isempty(obj.OriginalHTMLSource)
                obj.HtmlComponent.HTMLSource = obj.OriginalHTMLSource;
            end

            % Delete copied shim file
            if ~isempty(obj.CopiedShimPath) && isfile(obj.CopiedShimPath)
                try
                    delete(obj.CopiedShimPath);
                catch
                end
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

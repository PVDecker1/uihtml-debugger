classdef UIHTMLDevTools < handle
    % UIHTMLDevTools Injects Eruda dev tools into a uihtml component.
    %
    %   obj = UIHTMLDevTools(uihtmlComp) creates a dev tools injector for the given
    %   uihtml component.

    properties
        % Toggles the dev tools injection on/off. Default: true.
        Enabled (1,1) logical = true
    end

    properties (Access = private)
        % Reference to the uihtml component.
        HtmlComponent
        % Backup of the original HTMLSource.
        OriginalHTMLSource string = ""
        % Path to the temporary injected HTML file.
        TempHTMLPath string = ""
    end

    methods
        function set.Enabled(obj, val)
            if obj.Enabled == val
                return;
            end
            obj.Enabled = val;
            if obj.Enabled
                if strlength(string(obj.HtmlComponent.HTMLSource)) > 0
                    obj.injectEruda();
                end
            else
                obj.removeEruda();
            end
        end

        function obj = UIHTMLDevTools(uihtmlComp)
            % UIHTMLDevTools Constructor
            %
            %   obj = UIHTMLDevTools(uihtmlComp) attaches the dev tools to
            %   the provided uihtml component.
            arguments
                uihtmlComp
            end

            if ~isprop(uihtmlComp, "HTMLSource") && ~isfield(uihtmlComp, "HTMLSource")
                error("uihtmlDevTools:InvalidComponent", ...
                    "Provided component must have an HTMLSource property.");
            end

            obj.HtmlComponent = uihtmlComp;

            % Handle dev tools injection if HTMLSource is provided
            if strlength(string(uihtmlComp.HTMLSource)) > 0
                obj.injectEruda();
            end
        end % Constructor

        function delete(obj)
            % delete Destructor
            %
            %   Cleans up temporary files.
            obj.removeEruda();
        end % function delete
    end % methods

    methods (Access = private)
        function injectEruda(obj)
            % injectEruda Injects Eruda into a temporary copy of the HTML.
            source = string(obj.HtmlComponent.HTMLSource);
            obj.OriginalHTMLSource = source;

            % If it's a URL, we cannot inject the shim by file modification.
            if startsWith(source, "http://") || startsWith(source, "https://")
                error("uihtmlDevTools:UrlHTMLSource", ...
                    "URLs are not supported by UIHTMLDevTools");
            end

            % Read original HTML
            if isfile(source)
                htmlContent = fileread(source);
            else
                error("uihtmlDevTools:InvalidHTMLSource", ...
                    "HTML source must be a file.");
            end

            % Copy eruda.js to the target directory
            [targetDir, name, ext] = fileparts(source);
            if strlength(targetDir) == 0
                targetDir = pwd;
            end

            dSelf = fileparts(mfilename("fullpath"));
            pErudaSrc = fullfile(dSelf, "vendor", "eruda", "eruda.js");
            pErudaDest = fullfile(targetDir, "eruda.js");

            try
                copyfile(pErudaSrc, pErudaDest);
            catch
                error("uihtmlDevTools:ErudaCopyFailure", ...
                    "Failed to copy eruda.js to:\n%s", pErudaDest);
            end

            % Prepare the script block (Default bottom docking)
            scriptBlock = "<script src=""eruda.js""></script>" + newline + ...
                "<script>eruda.init();</script>";

            % Insert just before </body> or at the end
            [startIdx, ~] = regexpi(htmlContent, "</body>");
            if ~isempty(startIdx)
                insertPos = startIdx(1);
                newHtml = [htmlContent(1:insertPos-1), newline, char(scriptBlock), ...
                    newline, htmlContent(insertPos:end)];
            else
                newHtml = [htmlContent, newline, char(scriptBlock)];
            end

            % Write injected HTML to a temporary file in the same directory
            [~,uuid] = fileparts(tempname);
            obj.TempHTMLPath = fullfile(targetDir, name + "_devtools_" + uuid + ext);

            try
                writelines(newHtml, obj.TempHTMLPath);
            catch
                error("uihtmlDevTools:TempWriteFailure", ...
                    "Failed to write temporary html file to:\n%s", obj.TempHTMLPath);
            end

            % Update the component's HTMLSource with the temporary file path.
            obj.HtmlComponent.HTMLSource = "";
            obj.HtmlComponent.HTMLSource = obj.TempHTMLPath;
        end % function injectEruda

        function removeEruda(obj)
            % removeEruda Restores the original HTML and cleans up the temporary files.
            if isa(obj.HtmlComponent, "handle") && isvalid(obj.HtmlComponent) && ...
                    strlength(obj.OriginalHTMLSource) > 0
                try
                    obj.HtmlComponent.HTMLSource = obj.OriginalHTMLSource;
                catch
                    % Ignore restoration errors
                end
            end

            % Delete temporary HTML file
            if strlength(obj.TempHTMLPath) > 0 && isfile(obj.TempHTMLPath)
                try
                    delete(obj.TempHTMLPath);
                catch
                    warning("uihtmlDevTools:FailedCleanup", ...
                        "Failed to delete %s. Please check your file system", ...
                        obj.TempHTMLPath)
                end
            end

            % Delete copied eruda.js
            if strlength(obj.OriginalHTMLSource) > 0
                [targetDir, ~, ~] = fileparts(obj.OriginalHTMLSource);
                if strlength(targetDir) == 0
                    targetDir = pwd;
                end
                pErudaDest = fullfile(targetDir, "eruda.js");
                if isfile(pErudaDest)
                    try
                        delete(pErudaDest);
                    catch
                        warning("uihtmlDevTools:FailedCleanup", ...
                            "Failed to delete %s. Please check your file system", ...
                            pErudaDest)
                    end
                end
            end
        end % function removeEruda
    end % methods (Access = private)
end

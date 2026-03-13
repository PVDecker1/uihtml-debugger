function [rerouter, htmlComp] = custom_formatting()
% Example demonstrating how to use a custom formatter with the ConsoleErrorRerouter.

% Create a UI figure
fig = uifigure("Name", "Custom Formatting Example", "Position", [100, 100, 600, 400]);

% Create a UIHTML component
htmlComp = uihtml(fig, "Position", [10, 10, 580, 380]);

% Get the absolute path to the example HTML file
filePath = fullfile(fileparts(mfilename("fullpath")), "html", "example_page.html");

% Load the HTML content
htmlComp.HTMLSource = filePath;

% Create the rerouter
rerouter = ConsoleErrorRerouter(htmlComp);
rerouter.ErrorLevels = ["error", "warn", "info", "log", "debug"];

% Override the default FormatFcn with a custom function.
% The custom function must accept (level, message, stack) and return void.
rerouter.FormatFcn = @myCustomFormatter;

fprintf(1, "UI figure created. Click the buttons in the UI to generate console messages.\n");
fprintf(1, "Check the MATLAB Command Window for the custom rerouted output.\n");

end % function custom_formatting

function myCustomFormatter(level, message, stack)
    % A custom formatter that prefixes messages with a timestamp and handles
    % its own output.

    timestamp = string(datetime("now", "Format", "HH:mm:ss"));

    if matches(level, ["error", "warn"])
        % Output errors and warnings to standard error (red text)
        fprintf(2, "[%s] JS %s: %s\n", timestamp, upper(level), message);
        if ~isempty(stack)
            fprintf(2, "    Stack: %s\n", stack);
        end
    else
        % Output other levels to standard output
        fprintf(1, "[%s] JS %s: %s\n", timestamp, upper(level), message);
    end
end

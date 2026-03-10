% Example demonstrating how to use a custom formatter with the ConsoleErrorRerouter.

fig = uifigure('Name', 'Custom Formatting Example', 'Position', [100, 100, 600, 400]);
htmlComp = uihtml(fig, 'Position', [10, 10, 580, 380]);
filePath = fullfile(fileparts(mfilename('fullpath')), 'html', 'example_page.html');
htmlComp.HTMLSource = filePath;

rerouter = ConsoleErrorRerouter(htmlComp);

% Override the default FormatFcn with a custom function.
% The custom function must accept (level, message, stack) and return void.
rerouter.FormatFcn = @myCustomFormatter;

disp('UI figure created. Click the buttons in the UI to generate console messages.');
disp('Check the MATLAB Command Window for the custom rerouted output.');

function myCustomFormatter(level, message, stack)
    % A custom formatter that prefixes messages with a timestamp and handles
    % its own output.

    timestamp = datestr(now, 'HH:MM:SS');

    if level == "error" || level == "warn"
        % Output errors and warnings to standard error (red text)
        fprintf(2, '[%s] JS %s: %s\n', timestamp, upper(level), message);
        if ~isempty(stack)
            fprintf(2, '    Stack: %s\n', stack);
        end
    else
        % Output other levels to standard output
        fprintf(1, '[%s] JS %s: %s\n', timestamp, upper(level), message);
    end
end

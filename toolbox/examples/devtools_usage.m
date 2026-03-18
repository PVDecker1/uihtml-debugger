function [devTools, rerouter, htmlComp] = devtools_usage()
% Example demonstrating how to use UIHTMLDevTools alongside ConsoleErrorRerouter.
%
% This script creates a UI figure with an HTML component and attaches both 
% dev tools (Eruda) and the console rerouter.

% Create a UI figure
fig = uifigure("Name", "UIHTML Debugger Example", "Position", [100, 100, 800, 600]);

% Create a UIHTML component
htmlComp = uihtml(fig, "Position", [10, 10, 780, 580]);

% Get the absolute path to the example HTML file
% We use the one from the console rerouter examples for consistency
dExamples = fileparts(mfilename("fullpath"));
filePath = fullfile(dExamples, 'html', 'example_page.html');

% Load the HTML content
htmlComp.HTMLSource = filePath;

% 1. Attach UIHTMLDevTools
% This injects Eruda (mobile-like dev tools) into the UI itself.
% You will see a small 'cog' icon in the bottom right of the UI.
devTools = UIHTMLDevTools(htmlComp);

% 2. Attach the Console Error Rerouter
% This sends console.error/warn/etc. to the MATLAB Command Window.
rerouter = ConsoleErrorRerouter(htmlComp);
rerouter.ErrorLevels = ["error", "warn", "info", "log", "debug"];

fprintf(1, "UI figure created.\n");
fprintf(1, "1. Check the MATLAB Command Window for rerouted console output.\n");
fprintf(1, "2. Click the 'cog' icon in the bottom-right of the UI to open Eruda DevTools.\n");
fprintf(1, "3. Use the 'Enabled' property of devTools to toggle the injection.\n");

end % function devtools_usage
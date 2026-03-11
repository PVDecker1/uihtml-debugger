% Minimal example demonstrating how to use the ConsoleErrorRerouter.

% Create a UI figure
fig = uifigure('Name', 'Console Error Rerouter Example', 'Position', [100, 100, 600, 400]);

% Create a UIHTML component
htmlComp = uihtml(fig, 'Position', [10, 10, 580, 380]);

% Get the absolute path to the example HTML file
filePath = fullfile(fileparts(mfilename('fullpath')), 'html', 'example_page.html');

% Load the HTML content
htmlComp.HTMLSource = filePath;

% Create the rerouter, attaching it to the component.
% It intercepts 'error', 'warn', 'info', 'log', and 'debug' messages
% and outputs them to the Command Window natively.
rerouter = ConsoleErrorRerouter(htmlComp);
rerouter.ErrorLevels = ["error", "warn", "info", "log", "debug"];

disp('UI figure created. Click the buttons in the UI to generate console messages.');
disp('Check the MATLAB Command Window for the rerouted output.');

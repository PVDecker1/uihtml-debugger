%% Minimal UIHtml Error Debugger Example
% This demonstrates the minimal two-step process for using the debugger

% Create uihtml component
fig = uifigure('Name', 'Minimal Example');
h = uihtml(fig, 'Position', [10, 10, 400, 300]);

% Set HTML source (Step 1: HTML file must include the error rerouting script)
h.HTMLSource = fullfile(pwd, 'examples', 'minimal_example.html');

% Add the UIHtmlErrorLogger class to path
addpath(fullfile(pwd, 'src'));

% Step 2: Attach debugger class to uihtml component
errorLogger = UIHtmlErrorLogger(h);

% That's it! Now console errors from the HTML will appear in MATLAB command window
% Click the "Click to trigger error" button in the HTML to test
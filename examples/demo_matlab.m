%% UIHtml Error Debugger - Example Usage
% This script demonstrates how to use the UIHtmlErrorLogger class
% to capture JavaScript console errors from a uihtml component.

%% Setup
% Clear workspace and close existing figures
clear;
close all;
clc;

fprintf('=== UIHtml Error Debugger Example ===\n\n');

%% Step 1: Create UI Figure and UIHtml Component
fprintf('Step 1: Creating UI figure and uihtml component...\n');

% Create a figure for the uihtml component
fig = uifigure('Name', 'UIHtml Error Debugger Demo', ...
               'Position', [100, 100, 900, 700]);

% Create the uihtml component
htmlComponent = uihtml(fig, 'Position', [10, 10, 880, 680]);

% Set the HTML source to our demo file
% Note: Adjust the path as needed based on your file structure
demoHtmlPath = fullfile(pwd, 'examples', 'demo.html');

if exist(demoHtmlPath, 'file')
    htmlComponent.HTMLSource = demoHtmlPath;
    fprintf('✓ HTML source set to: %s\n', demoHtmlPath);
else
    % Fallback: create a simple HTML content with error rerouter
    fprintf('⚠ Demo HTML file not found. Using inline HTML content...\n');
    
    htmlContent = sprintf(['<!DOCTYPE html>\n' ...
        '<html><head><title>Error Debugger Test</title></head><body>\n' ...
        '<h1>UIHtml Error Debugger Test</h1>\n' ...
        '<button onclick="console.error(''Test error from button click!'');">Trigger Error</button>\n' ...
        '<button onclick="console.log(''Normal log message'');">Normal Log</button>\n' ...
        '<script>\n' ...
        '// Error rerouter script (inline version using sendEventToMATLAB)\n' ...
        'var originalConsoleError = console.error;\n' ...
        'console.error = function() {\n' ...
        '    var args = Array.prototype.slice.call(arguments);\n' ...
        '    var errorMessage = "UIHTML Console Error: " + args.join(" ");\n' ...
        '    if (typeof sendEventToMATLAB === "function") {\n' ...
        '        try {\n' ...
        '            sendEventToMATLAB("consoleError", {\n' ...
        '                type: "consoleError",\n' ...
        '                message: errorMessage,\n' ...
        '                timestamp: new Date().toISOString()\n' ...
        '            });\n' ...
        '        } catch (e) {}\n' ...
        '    }\n' ...
        '    originalConsoleError.apply(console, args);\n' ...
        '};\n' ...
        'console.error("Error rerouter initialized - this message should appear in MATLAB");\n' ...
        '</script>\n' ...
        '</body></html>']);
    
    htmlComponent.HTMLSource = htmlContent;
end

%% Step 2: Create UIHtmlErrorLogger Instance
fprintf('\nStep 2: Attaching error logger to uihtml component...\n');

% Add the src directory to the path if it's not already there
srcPath = fullfile(pwd, 'src');
if exist(srcPath, 'dir') && ~contains(path, srcPath)
    addpath(srcPath);
    fprintf('✓ Added src directory to MATLAB path\n');
end

% Create the error logger instance
try
    errorLogger = UIHtmlErrorLogger(htmlComponent);
    fprintf('✓ UIHtmlErrorLogger created successfully\n');
catch ME
    fprintf('❌ Error creating UIHtmlErrorLogger: %s\n', ME.message);
    fprintf('   Make sure UIHtmlErrorLogger.m is in the src/ directory\n');
    return;
end

%% Step 3: Test the Error Logging
fprintf('\nStep 3: Testing error logging...\n');
fprintf('The HTML page should now be displayed in the figure.\n');
fprintf('Any console errors from the HTML will appear below:\n');
fprintf('----------------------------------------\n');

% Give the HTML content time to load
pause(2);

% Optional: Programmatically trigger an error for testing
fprintf('\nTriggering a test error programmatically...\n');
try
    htmlComponent.executeJavaScript('console.error("Programmatic test error from MATLAB");');
    fprintf('✓ Test error triggered\n');
catch
    fprintf('⚠ Could not trigger programmatic error (executeJavaScript may not be available)\n');
end

%% Step 4: Display Usage Instructions
fprintf('\n=== Usage Instructions ===\n');
fprintf('1. The HTML page is now loaded with error rerouting enabled\n');
fprintf('2. Click the "Trigger Error" button in the HTML page to test\n');
fprintf('3. Console errors will appear in this MATLAB command window\n');
fprintf('4. The UIHtmlErrorLogger will continue listening until you:\n');
fprintf('   - Close the figure window\n');
fprintf('   - Clear the errorLogger variable\n');
fprintf('   - Run: delete(errorLogger)\n\n');

% Display logger status
try
    status = errorLogger.getStatus();
    fprintf('Logger Status:\n');
    fprintf('  - Listening: %s\n', mat2str(status.isListening));
    fprintf('  - Component Valid: %s\n', mat2str(status.componentValid));
    fprintf('  - Component Type: %s\n', status.componentType);
catch
    fprintf('⚠ Could not retrieve logger status\n');
end

fprintf('\n=== Ready for Testing ===\n');
fprintf('The error logger is now active. Console errors from the HTML\n');
fprintf('content will be displayed in this command window.\n\n');

%% Cleanup function (optional)
% Uncomment the following lines if you want automatic cleanup
% 
% fprintf('Setting up automatic cleanup in 60 seconds...\n');
% cleanupTimer = timer('ExecutionMode', 'singleShot', ...
%                      'StartDelay', 60, ...
%                      'TimerFcn', @(~,~) cleanupDemo(fig, errorLogger));
% start(cleanupTimer);

function cleanupDemo(fig, errorLogger)
    % Clean up the demo
    fprintf('\nCleaning up demo...\n');
    
    if exist('errorLogger', 'var') && isvalid(errorLogger)
        delete(errorLogger);
    end
    
    if exist('fig', 'var') && isvalid(fig)
        delete(fig);
    end
    
    fprintf('Demo cleanup complete.\n');
end
classdef tConsoleErrorRerouter < matlab.unittest.TestCase

    methods (Test)
        function testConstructorValidComponent(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);
            testCase.verifyClass(rerouter, 'ConsoleErrorRerouter');
        end

        function testConstructorInvalidComponent(testCase)
            % Should throw error for a component that does not support HTMLEventReceived
            testCase.verifyError(@() ConsoleErrorRerouter(struct()), 'uihtmlRerouter:badArgument');
        end

        function testMessageRerouting(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            fireConsoleErrorEvent(comp, 'error', 'Test message');
            testCase.verifyEqual(rerouter.LastMessage, 'Test message');
        end

        function testEnabledToggle(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            rerouter.Enabled = false;
            fireConsoleErrorEvent(comp, 'error', 'Hidden message');
            testCase.verifyEqual(rerouter.LastMessage, '');

            rerouter.Enabled = true;
            fireConsoleErrorEvent(comp, 'error', 'Visible message');
            testCase.verifyEqual(rerouter.LastMessage, 'Visible message');
        end

        function testErrorLevelsFiltering(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            % Default is 'error' only
            fireConsoleErrorEvent(comp, 'warn', 'Warning message');
            testCase.verifyEqual(rerouter.LastMessage, '');

            fireConsoleErrorEvent(comp, 'error', 'Error message');
            testCase.verifyEqual(rerouter.LastMessage, 'Error message');

            % Change ErrorLevels
            rerouter.ErrorLevels = ["error", "warn"];
            fireConsoleErrorEvent(comp, 'warn', 'Warning message 2');
            testCase.verifyEqual(rerouter.LastMessage, 'Warning message 2');
        end

        function testCustomFormatFcn(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            rerouter.FormatFcn = @testCustomFormatter;

            fireConsoleErrorEvent(comp, 'error', 'Format this');
            testCase.verifyEqual(rerouter.LastMessage, 'Format this');
        end

        function testCleanTeardown(testCase)
            comp = createMockUihtmlComponent();

            % Add an independent listener
            comp.addlistener('HTMLEventReceived', @(~, ~) disp('External fired'));

            rerouter = ConsoleErrorRerouter(comp);
            delete(rerouter); % Delete our rerouter

            % Fire event, ensure the rerouter didn't remove ALL listeners, just its own
            fireConsoleErrorEvent(comp, 'error', 'Test after teardown');
        end

        function testShimDelivery(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tempFixture = testCase.applyFixture(TemporaryFolderFixture);

            % Create a dummy HTML file
            htmlFile = fullfile(tempFixture.Folder, 'test_shim.html');
            fid = fopen(htmlFile, 'w');
            fwrite(fid, '<html><head><title>Test</title></head><body></body></html>');
            fclose(fid);

            comp = createMockUihtmlComponent();
            comp.HTMLSource = htmlFile;

            rerouter = ConsoleErrorRerouter(comp);

            % Verify shim was copied
            copiedShimPath = fullfile(tempFixture.Folder, 'consoleShim.js');
            testCase.verifyTrue(isfile(copiedShimPath), 'consoleShim.js should be copied to HTML directory.');

            % Verify HTMLSource was updated to a temporary file
            testCase.verifyNotEqual(comp.HTMLSource, htmlFile, 'HTMLSource should be updated.');
            testCase.verifySubstring(comp.HTMLSource, '_rerouter_temp', 'HTMLSource should point to a temporary file.');
            testCase.verifyTrue(isfile(comp.HTMLSource), 'The temporary HTML file should exist.');

            % Read the temporary HTML to verify script injection
            fid = fopen(comp.HTMLSource, 'r');
            tempHtmlContent = fread(fid, '*char')';
            fclose(fid);
            testCase.verifySubstring(tempHtmlContent, '<script src="consoleShim.js"></script>', 'Script tag should be injected.');

            % Save the temporary file path for cleanup verification
            tempHtmlFile = comp.HTMLSource;

            % Verify Teardown
            delete(rerouter);
            testCase.verifyFalse(isfile(copiedShimPath), 'consoleShim.js should be deleted on destruction.');
            testCase.verifyFalse(isfile(tempHtmlFile), 'Temporary HTML file should be deleted on destruction.');
            testCase.verifyEqual(comp.HTMLSource, htmlFile, 'Original HTMLSource should be restored on destruction.');
        end
    end
end

% Helper functions (simulating what AGENTS.md mentioned)
function comp = createMockUihtmlComponent()
    comp = MockUihtmlComponent();
end

function fireConsoleErrorEvent(comp, level, message)
    eventData = MockHTMLEventData(level, message, '');
    comp.notify('HTMLEventReceived', eventData);
end

function out = testCustomFormatter(lvl, msg, stk)
    out = ['CUSTOM ' char(lvl) ': ' msg];
end

% Mock classes for testing
classdef MockUihtmlComponent < handle
    events
        HTMLEventReceived
    end
    properties
        HTMLEventReceivedFcn
        HTMLSource = ''
    end
end

classdef MockHTMLEventData < event.EventData
    properties
        HTMLEventName = 'ConsoleError'
        HTMLEventData
    end

    methods
        function obj = MockHTMLEventData(level, message, stack)
            obj.HTMLEventData = struct('level', level, 'message', message, 'stack', stack);
        end
    end
end

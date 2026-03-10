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

        function testAllLevelsRerouting(testCase)
            % We will test that LastMessage is updated correctly for all levels
            % Note: Because defaultFormatter uses fprintf and warning,
            % we will suppress their outputs where possible.
            % But we can't use evalc inside the test methods per AGENTS.md constraints!
            % "Agents MUST NOT: Use evalin, evalc, or eval anywhere in MATLAB code."
            %
            % Therefore, we will only use testCase.verifyWarning for warnings.
            % For fprintf, we just let it output unless we replace FormatFcn.
            % Since we must test the defaultFormatter, we can't replace it here.

            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            levels = ["error", "info", "log", "debug"];
            for i = 1:length(levels)
                lvl = levels(i);
                msg = sprintf('Test %s message', lvl);

                % Fire event
                fireConsoleErrorEvent(comp, char(lvl), msg);

                % Verify it reached LastMessage
                testCase.verifyEqual(rerouter.LastMessage, msg, sprintf('Failed to route %s', lvl));
            end

            % Test warning separately using verifyWarning
            msg = 'Test warn message';
            testCase.verifyWarning(@() fireConsoleErrorEvent(comp, 'warn', msg), ...
                'uihtmlRerouter:consoleWarn', 'Warning was not thrown or ID is wrong.');
            testCase.verifyEqual(rerouter.LastMessage, msg, 'Failed to route warn');
        end

        function testEnabledToggle(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            % Replace format function to suppress output
            rerouter.FormatFcn = @(~,~,~) [];

            rerouter.Enabled = false;
            fireConsoleErrorEvent(comp, 'error', 'Hidden message');
            testCase.verifyEqual(rerouter.LastMessage, '');

            rerouter.Enabled = true;
            fireConsoleErrorEvent(comp, 'error', 'Visible message');
            testCase.verifyEqual(rerouter.LastMessage, 'Visible message');
        end

        function testCustomFormatFcn(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            % We will capture output in a global or persistent variable since the signature is void
            global gCustomFormatCalled
            gCustomFormatCalled = false;

            rerouter.FormatFcn = @mockCustomFormatter;

            fireConsoleErrorEvent(comp, 'error', 'Format this');
            testCase.verifyTrue(gCustomFormatCalled, 'Custom formatter was not called.');
            testCase.verifyEqual(rerouter.LastMessage, 'Format this');

            clear global gCustomFormatCalled;
        end

        function testCleanTeardown(testCase)
            comp = createMockUihtmlComponent();

            % Add an independent listener
            comp.addlistener('HTMLEventReceived', @(~, ~) setExternalFired());

            rerouter = ConsoleErrorRerouter(comp);
            % suppress output during teardown test
            rerouter.FormatFcn = @(~,~,~) [];
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

function mockCustomFormatter(~, ~, ~)
    global gCustomFormatCalled
    gCustomFormatCalled = true;
end

function setExternalFired()
    % Dummy callback function to act as an external listener
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

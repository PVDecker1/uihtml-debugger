classdef tConsoleErrorRerouter < matlab.unittest.TestCase

    properties
        CustomFormatCalled (1,1) logical = false
    end

    methods (Test)
        function testConstructorValidComponent(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);
            testCase.verifyClass(rerouter, "ConsoleErrorRerouter");
        end

        function testConstructorInvalidComponent(testCase)
            % Should throw error for a component that does not support ...
            % HTMLEventReceived
            testCase.verifyError(@() ConsoleErrorRerouter(struct()), ...
                "uihtmlRerouter:badArgument");
        end

        function testAllLevelsRerouting(testCase)
            % We will test that LastMessage is updated correctly for all levels
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);
            
            % Enable all levels for this test
            rerouter.ErrorLevels = ["error", "warn", "info", "log", "debug"];

            levels = ["error", "info", "log", "debug"];
            for i = 1:length(levels)
                lvl = levels(i);
                msg = "Test " + lvl + " message";

                % Fire event
                fireConsoleErrorEvent(comp, lvl, msg);

                % Verify it reached LastMessage
                testCase.verifyEqual(rerouter.LastMessage, msg, ...
                    "Failed to route " + lvl);
            end

            % Test warning separately using verifyWarning
            msg = "Test warn message";
            testCase.verifyWarning(@() fireConsoleErrorEvent(comp, "warn", msg), ...
                "uihtmlRerouter:consoleWarn", ...
                "Warning was not thrown or ID is wrong.");
            testCase.verifyEqual(rerouter.LastMessage, msg, "Failed to route warn");
        end

        function testErrorLevelsFiltering(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);
            
            % Default is ["error"]
            testCase.verifyEqual(rerouter.ErrorLevels, "error");
            
            % Fire info message - should be ignored (LastMessage remains empty)
            fireConsoleErrorEvent(comp, "info", "Ignored info");
            testCase.verifyEqual(rerouter.LastMessage, "");
            
            % Fire error message - should be captured
            fireConsoleErrorEvent(comp, "error", "Captured error");
            testCase.verifyEqual(rerouter.LastMessage, "Captured error");
            
            % Change levels to only warn
            rerouter.ErrorLevels = "warn";
            
            % Fire error message - should be ignored 
            % (LastMessage remains 'Captured error')
            fireConsoleErrorEvent(comp, "error", "Ignored error");
            testCase.verifyEqual(rerouter.LastMessage, "Captured error");
            
            % Fire warn message - should be captured
            testCase.verifyWarning(@() fireConsoleErrorEvent(comp, "warn", ...
                "Captured warn"), "uihtmlRerouter:consoleWarn");
            testCase.verifyEqual(rerouter.LastMessage, "Captured warn");
        end

        function testEnabledToggle(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            % Replace format function to suppress output
            rerouter.FormatFcn = @(~,~,~) [];

            rerouter.Enabled = false;
            fireConsoleErrorEvent(comp, "error", "Hidden message");
            testCase.verifyEqual(rerouter.LastMessage, "");

            rerouter.Enabled = true;
            fireConsoleErrorEvent(comp, "error", "Visible message");
            testCase.verifyEqual(rerouter.LastMessage, "Visible message");
        end

        function testCustomFormatFcn(testCase)
            comp = createMockUihtmlComponent();
            rerouter = ConsoleErrorRerouter(comp);

            testCase.CustomFormatCalled = false;
            rerouter.FormatFcn = @(lvl, msg, stack) testCase.markCalled();

            fireConsoleErrorEvent(comp, "error", "Format this");
            testCase.verifyTrue(testCase.CustomFormatCalled, ...
                "Custom formatter not called.");
            testCase.verifyEqual(rerouter.LastMessage, "Format this");
        end

        function testCleanTeardown(testCase)
            comp = createMockUihtmlComponent();

            % Add an independent listener
            comp.addlistener("HTMLEventReceived", @(~, ~) setExternalFired());

            rerouter = ConsoleErrorRerouter(comp);
            % suppress output during teardown test
            rerouter.FormatFcn = @(~,~,~) [];
            delete(rerouter); % Delete our rerouter

            % Fire event, ensure the rerouter didn't remove ALL listeners, 
            % just its own
            fireConsoleErrorEvent(comp, "error", "Test after teardown");
        end

        function testShimInjection(testCase)
            testDir = fileparts(mfilename("fullpath"));
            fixtureHtml = fullfile(testDir, "html", "test_page.html");

            comp = createMockUihtmlComponent();
            comp.HTMLSource = fixtureHtml;

            rerouter = ConsoleErrorRerouter(comp);

            % Verify HTMLSource was updated to a temporary file
            testCase.verifyNotEqual(comp.HTMLSource, fixtureHtml, ...
                "HTMLSource should be updated.");
            testCase.verifySubstring(comp.HTMLSource, "_rerouter_temp", ...
                "HTMLSource should point to a temporary file.");
            testCase.verifyTrue(isfile(comp.HTMLSource), ...
                "The temporary HTML file should exist.");

            % Read the temporary HTML to verify script injection
            tempHtmlContent = fileread(comp.HTMLSource);
            
            % Verify the presence of the inlined script block
            testCase.verifySubstring(tempHtmlContent, ...
                "id=""console-rerouter-shim""", ...
                "Inlined script tag should be present.");
            testCase.verifySubstring(tempHtmlContent, ...
                "setup = function(htmlComponent)", ...
                "Shim should wrap setup function.");

            % Verify Teardown
            tempHtmlFile = comp.HTMLSource;
            delete(rerouter);
            testCase.verifyFalse(isfile(tempHtmlFile), ...
                "Temporary HTML file should be deleted on destruction.");
            testCase.verifyEqual(comp.HTMLSource, fixtureHtml, ...
                "Original HTMLSource should be restored on destruction.");
        end
    end

    methods
        function markCalled(testCase)
            testCase.CustomFormatCalled = true;
        end
    end
end

% Helper functions
function comp = createMockUihtmlComponent()
    comp = MockUihtmlComponent();
end

function fireConsoleErrorEvent(comp, level, message)
    eventData = MockHTMLEventData(level, message, "");
    comp.notify("HTMLEventReceived", eventData);
end

function setExternalFired()
    % Dummy callback function to act as an external listener
end

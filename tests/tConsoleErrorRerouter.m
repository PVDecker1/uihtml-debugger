classdef tConsoleErrorRerouter < matlab.mock.TestCase
    properties
        Figure
        Component
        FixtureHtml string
        Rerouter
        ReadyFired = 0
    end % properties

    methods (TestMethodSetup)
        function createComponent(testCase)
            % Create a real uihtml component because matlab.ui.control.HTML 
            % is Sealed and cannot be mocked via createMock.
            testCase.Figure = uifigure('Visible', 'off');
            testCase.Component = uihtml(testCase.Figure);
            
            % Reset counter
            testCase.ReadyFired = 0;
            
            % Use addlistener to ensure it stays alive
            addlistener(testCase.Component, "HTMLEventReceived", ...
                @(src, event) testCase.handleGlobalEvents(event));

            % Set HTMLSource
            testDir = fileparts(mfilename("fullpath"));
            testCase.FixtureHtml = string(fullfile(testDir, "html", "test_page.html"));
            testCase.Component.HTMLSource = testCase.FixtureHtml;

            % Wait for initial Ready
            testCase.waitForReady(0);

            % Ensure cleanup
            testCase.addTeardown(@() delete(testCase.Figure));
        end % function createComponent(testCase)
    end % methods (TestMethodSetup)

    methods
        function handleGlobalEvents(testCase, event)
            if matches(event.HTMLEventName, "Ready")
                testCase.ReadyFired = testCase.ReadyFired + 1;
            end
        end % function handleGlobalEvents

        function waitForReady(testCase, initialCount)
            t = tic;
            while testCase.ReadyFired <= initialCount && toc(t) < 15
                pause(0.1);
            end
        end % function waitForReady
    end % methods

    methods (Test)
        function testConstructorValidComponent(testCase)
            testCase.Rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.verifyClass(testCase.Rerouter, "ConsoleErrorRerouter");
        end % function testConstructorValidComponent

        function testConstructorInvalidComponent(testCase)
            testCase.verifyError(@() ConsoleErrorRerouter(struct()), ...
                "MATLAB:validation:UnableToConvert");
        end % function testConstructorInvalidComponent

        function testAllLevelsRerouting(testCase)
            initialReady = testCase.ReadyFired;
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.Rerouter = rerouter;
            
            % ConsoleErrorRerouter constructor causes a reload. Wait for it.
            testCase.waitForReady(initialReady);

            rerouter.ErrorLevels = ["error", "warn", "info", "log", "debug"];

            levels = ["error", "info", "log", "debug"];
            for lvl = levels
                msg = "Test " + lvl + " message";
                testCase.triggerAndWait(rerouter, lvl, msg);
                testCase.verifySubstring(rerouter.LastMessage, msg, "Failed to route " + lvl);
            end

            msg = "Test warn message";
            testCase.verifyWarning(@() testCase.triggerAndWait(rerouter, "warn", msg), ...
                "uihtmlRerouter:consoleWarn");
            testCase.verifySubstring(rerouter.LastMessage, msg, "Failed to route warn");
        end % function testAllLevelsRerouting

        function testErrorLevelsFiltering(testCase)
            initialReady = testCase.ReadyFired;
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.Rerouter = rerouter;
            testCase.waitForReady(initialReady);

            testCase.verifyEqual(rerouter.ErrorLevels, "error");
            
            testCase.triggerJS("info", "Ignored info");
            pause(0.5); 
            testCase.verifyNotSubstring(rerouter.LastMessage, "Ignored info");
            
            testCase.triggerAndWait(rerouter, "error", "Captured error");
            testCase.verifySubstring(rerouter.LastMessage, "Captured error");
            
            rerouter.ErrorLevels = "warn";
            testCase.triggerJS("error", "Ignored error");
            pause(0.5);
            testCase.verifySubstring(rerouter.LastMessage, "Captured error");
            
            testCase.verifyWarning(@() testCase.triggerAndWait(rerouter, "warn", "Captured warn"), ...
                "uihtmlRerouter:consoleWarn");
            testCase.verifySubstring(rerouter.LastMessage, "Captured warn");
        end % function testErrorLevelsFiltering

        function testEnabledToggle(testCase)
            initialReady = testCase.ReadyFired;
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.Rerouter = rerouter;
            testCase.waitForReady(initialReady);
            rerouter.FormatFcn = @(~,~,~) [];

            rerouter.Enabled = false;
            testCase.triggerJS("error", "Hidden message");
            pause(0.5);
            testCase.verifyNotSubstring(rerouter.LastMessage, "Hidden message");

            rerouter.Enabled = true;
            testCase.triggerAndWait(rerouter, "error", "Visible message");
            testCase.verifySubstring(rerouter.LastMessage, "Visible message");
        end % function testEnabledToggle

        function testCustomFormatFcn(testCase)
            initialReady = testCase.ReadyFired;
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.Rerouter = rerouter;
            testCase.waitForReady(initialReady);

            called = false;
            capturedLevel = "";
            rerouter.FormatFcn = @(lvl, msg, stack) assignCalled(lvl);
            function assignCalled(lvl)
                called = true;
                capturedLevel = lvl;
            end

            testCase.triggerAndWait(rerouter, "error", "Format this");
            testCase.verifyTrue(called, "Custom formatter not called.");
            testCase.verifyEqual(capturedLevel, "error");
        end % function testCustomFormatFcn

        function testCleanTeardown(testCase)
            initialReady = testCase.ReadyFired;
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.Rerouter = rerouter;
            testCase.waitForReady(initialReady);
            
            rerouter.FormatFcn = @(~,~,~) [];
            
            midReadyCount = testCase.ReadyFired;
            delete(rerouter);
            
            % Wait for teardown reload
            testCase.waitForReady(midReadyCount);
            testCase.verifyGreaterThan(testCase.ReadyFired, midReadyCount, ...
                "External listener should still fire after teardown reload.");
        end % function testCleanTeardown

        function testShimInjection(testCase)
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.Rerouter = rerouter;

            testCase.verifyNotEqual(string(testCase.Component.HTMLSource), testCase.FixtureHtml);
            testCase.verifySubstring(string(testCase.Component.HTMLSource), "_rerouter_");
            
            tempFile = string(testCase.Component.HTMLSource);
            testCase.verifyTrue(isfile(tempFile));

            delete(rerouter);
            testCase.verifyEqual(string(testCase.Component.HTMLSource), testCase.FixtureHtml);
            testCase.verifyFalse(isfile(tempFile));
        end % function testShimInjection
    end % methods (Test)

    methods (Access = private)
        function waitForMessage(~, rerouter, expectedMsg)
            t = tic;
            while ~contains(rerouter.LastMessage, expectedMsg) && toc(t) < 15
                pause(0.1);
            end
        end % function waitForMessage

        function triggerJS(testCase, level, msg)
            sendEventToHTMLSource(testCase.Component, "triggerTest", ...
                struct("level", char(level), "msg", char(msg)));
        end % function triggerJS

        function triggerAndWait(testCase, rerouter, level, msg)
            testCase.triggerJS(level, msg);
            testCase.waitForMessage(rerouter, msg);
        end % function triggerAndWait

        function verifyNotSubstring(testCase, actual, sub)
            testCase.verifyTrue(~contains(actual, sub), ...
                sprintf("Expected '%s' to NOT contain '%s'", actual, sub));
        end % function verifyNotSubstring
    end % methods (Access = private)
end % classdef tConsoleErrorRerouter
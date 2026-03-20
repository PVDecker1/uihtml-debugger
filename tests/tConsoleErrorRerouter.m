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
                "ConsoleErrorRerouter:InvalidComponent");
        end % function testConstructorInvalidComponent

        function testConstructorNoSource(testCase)
            testCase.Component.HTMLSource = "";
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.addTeardown(@() delete(rerouter));
            testCase.verifyEqual(string(testCase.Component.HTMLSource), "");
        end % function testConstructorNoSource

        function testUrlSourceMock(testCase)
            mockComp = MockComponent();
            mockComp.HTMLSource = "http://example.com";
            testCase.verifyError(@() ConsoleErrorRerouter(mockComp), ...
                "ConsoleErrorRerouter:UrlHTMLSource");
        end % function testUrlSourceMock

        function testInvalidFileSourceMock(testCase)
            mockComp = MockComponent();
            mockComp.HTMLSource = "non_existent_file.html";
            testCase.verifyError(@() ConsoleErrorRerouter(mockComp), ...
                "ConsoleErrorRerouter:InvalidHTMLSource");
        end % function testInvalidFileSourceMock

        function testNoBodyTag(testCase)
            tempDir = tempname;
            mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            noBodyHtml = fullfile(tempDir, "test_no_body.html");
            writelines("<html><p>No body</p></html>", noBodyHtml);
            
            mockComp = MockComponent();
            mockComp.HTMLSource = noBodyHtml;
            rerouter = ConsoleErrorRerouter(mockComp);
            testCase.Rerouter = rerouter;

            tempFile = string(mockComp.HTMLSource);
            content = fileread(tempFile);
            testCase.verifySubstring(content, "ConsoleError"); % Shim event name
        end % function testNoBodyTag

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

        function testPayloadEdgeCases(testCase)
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.Rerouter = rerouter;
            
            % Mock event data
            eventData = struct('HTMLEventName', "ConsoleError", ...
                'HTMLEventData', struct('level', 'error', 'message', 'Test message'));
            
            % No level
            badData = struct('HTMLEventName', "ConsoleError", ...
                'HTMLEventData', struct('message', 'No level'));
            rerouter.onHTMLEventReceived([], badData);
            testCase.verifyNotSubstring(rerouter.LastMessage, "No level");
            
            % Non-struct payload
            badData = struct('HTMLEventName', "ConsoleError", ...
                'HTMLEventData', "not a struct");
            rerouter.onHTMLEventReceived([], badData);
            
            % Missing stack (should not error)
            goodData = struct('HTMLEventName', "ConsoleError", ...
                'HTMLEventData', struct('level', 'error', 'message', 'No stack'));
            rerouter.onHTMLEventReceived([], goodData);
            testCase.verifySubstring(rerouter.LastMessage, "No stack");

            % Object payload (instead of struct)
            mockPayload = struct('level', 'error', 'message', 'Object message');
            objData = struct('HTMLEventName', "ConsoleError", ...
                'HTMLEventData', mockPayload);
            rerouter.onHTMLEventReceived([], objData);
            testCase.verifySubstring(rerouter.LastMessage, "Object message");

            % Missing level
            badData = struct('HTMLEventName', "ConsoleError", ...
                'HTMLEventData', struct('message', 'No level'));
            % We can't set LastMessage, but we know it should NOT be "No level"
            % It currently is "Object message" from previous step
            rerouter.onHTMLEventReceived([], badData);
            testCase.verifyEqual(rerouter.LastMessage, "Object message");

            % Other event name
            otherData = struct('HTMLEventName', "OtherEvent", ...
                'HTMLEventData', struct('level', 'error', 'message', 'Ignored'));
            rerouter.onHTMLEventReceived([], otherData);
            testCase.verifyEqual(rerouter.LastMessage, "Object message");
        end % function testPayloadEdgeCases

        function testListenerSetupFailure(testCase)
            tempDir = tempname;
            mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            htmlFile = fullfile(tempDir, "test.html");
            writelines("<html></html>", htmlFile);
            
            % Create a struct that doesn't support listeners but has valid HTMLSource
            mock = struct('HTMLSource', htmlFile);
            rerouter = ConsoleErrorRerouter(mock);
            testCase.addTeardown(@() delete(rerouter));
            testCase.verifyClass(rerouter, "ConsoleErrorRerouter");
        end % function testListenerSetupFailure

        function testDeleteInvalidComponent(testCase)
            rerouter = ConsoleErrorRerouter(testCase.Component);
            testCase.Rerouter = rerouter;
            delete(testCase.Figure); % Deletes component too
            delete(rerouter); % Should not error in removeShim
            testCase.Rerouter = [];
        end % function testDeleteInvalidComponent

        function testOriginalSourceDeleted(testCase)
            tempDir = tempname;
            mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            htmlFile = fullfile(tempDir, "temp.html");
            writelines("<html><body></body></html>", htmlFile);
            
            mockComp = MockComponent();
            mockComp.HTMLSource = htmlFile;
            rerouter = ConsoleErrorRerouter(mockComp);
            
            % Delete original source before rerouter is deleted
            delete(htmlFile);
            
            % removeShim should handle this gracefully
            delete(rerouter);
            testCase.verifyEqual(string(mockComp.HTMLSource), string(htmlFile));
        end % function testOriginalSourceDeleted
        
        function testCleanupWarnings(testCase)
            if isunix
                tempDir = tempname;
                mkdir(tempDir);
                testCase.addTeardown(@() rmdir(tempDir, 's'));
                htmlFile = fullfile(tempDir, "test.html");
                writelines("<html><body></body></html>", htmlFile);
                
                mockComp = MockComponent();
                mockComp.HTMLSource = htmlFile;
                rerouter = ConsoleErrorRerouter(mockComp);
                
                % Make the temp file read-only so delete(rerouter) fails to delete it
                tempFile = string(mockComp.HTMLSource);
                fileattrib(tempFile, '-w');
                testCase.addTeardown(@() fileattrib(tempFile, '+w'));
                
                testCase.verifyWarning(@() delete(rerouter), "ConsoleErrorRerouter:FailedCleanup");
            end
        end % function testCleanupWarnings

        function testTempWriteFailure(testCase)
            if isunix
                % On Unix, we can easily make a directory read-only
                tempDir = tempname;
                mkdir(tempDir);
                testCase.addTeardown(@() rmdir(tempDir, 's'));
                htmlFile = fullfile(tempDir, "test.html");
                writelines("<html></html>", htmlFile);
                
                % Make dir read-only
                fileattrib(tempDir, '-w');
                testCase.addTeardown(@() fileattrib(tempDir, '+w'));
                
                mockComp = MockComponent();
                mockComp.HTMLSource = htmlFile;
                testCase.verifyError(@() ConsoleErrorRerouter(mockComp), ...
                    "ConsoleErrorRerouter:TempWriteFailure");
            else
                % On Windows, it's harder to reliably trigger this via attributes,
                % so we might skip or use a different trick if needed.
                % For now, we'll assume unix coverage in CI is enough or skip.
            end
        end % function testTempWriteFailure

        function testEmptyTargetDir(testCase)
            origDir = pwd;
            tempDir = tempname;
            mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            testCase.addTeardown(@() cd(origDir));
            
            testFile = which(mfilename);
            testDir = fileparts(testFile);
            origHtml = fullfile(testDir, "html", "test_page.html");
            copyfile(origHtml, fullfile(tempDir, "test.html"));
            
            cd(tempDir);
            mockComp = MockComponent();
            mockComp.HTMLSource = "test.html";
            
            rerouter = ConsoleErrorRerouter(mockComp);
            testCase.Rerouter = rerouter;
            
            testCase.verifySubstring(string(mockComp.HTMLSource), "_rerouter_");
        end % function testEmptyTargetDir
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
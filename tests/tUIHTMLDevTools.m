classdef tUIHTMLDevTools < matlab.unittest.TestCase
    properties
        Figure
        Component
        FixtureHtml string
        DevTools
    end % properties

    methods (TestMethodSetup)
        function createComponent(testCase)
            % Create a real uihtml component because matlab.ui.control.HTML
            % is Sealed and cannot be mocked via createMock.
            testCase.Figure = uifigure('Visible', 'off');
            testCase.Component = uihtml(testCase.Figure);

            % Set HTMLSource
            testFile = which(mfilename);
            testDir = fileparts(testFile);
            testCase.FixtureHtml = string(fullfile(testDir, "html", "test_page.html"));
            testCase.Component.HTMLSource = testCase.FixtureHtml;

            % Ensure cleanup
            testCase.addTeardown(@() delete(testCase.Figure));
        end % function createComponent(testCase)
    end % methods (TestMethodSetup)

    methods (Test)
        function testConstructorValidComponent(testCase)
            testCase.DevTools = UIHTMLDevTools(testCase.Component);
            testCase.verifyClass(testCase.DevTools, "UIHTMLDevTools");
        end % function testConstructorValidComponent

        function testConstructorInvalidComponent(testCase)
            testCase.verifyError(@() UIHTMLDevTools(struct()), ...
                "uihtmlDevTools:InvalidComponent");
        end % function testConstructorInvalidComponent

        function testConstructorNoSource(testCase)
            testCase.Component.HTMLSource = "";
            devTools = UIHTMLDevTools(testCase.Component);
            testCase.addTeardown(@() delete(devTools));
            testCase.verifyEqual(string(testCase.Component.HTMLSource), "");
        end % function testConstructorNoSource

        function testInjection(testCase)
            devTools = UIHTMLDevTools(testCase.Component);
            testCase.DevTools = devTools;

            % Temporary HTML file is created
            testCase.verifyNotEqual(string(testCase.Component.HTMLSource), testCase.FixtureHtml);
            testCase.verifySubstring(string(testCase.Component.HTMLSource), "_devtools_");

            tempFile = string(testCase.Component.HTMLSource);
            testCase.verifyTrue(isfile(tempFile));

            % Temp HTML contains eruda.js script tag
            content = fileread(tempFile);
            testCase.verifySubstring(content, "<script src=""eruda.js""></script>");
            testCase.verifySubstring(content, "<script>eruda.init();</script>");

            % Copied eruda.js exists in the HTML file's directory after construction
            targetDir = fileparts(testCase.FixtureHtml);
            pErudaDest = fullfile(targetDir, "eruda.js");
            testCase.verifyTrue(isfile(pErudaDest));
        end % function testInjection

        function testEnabledToggle(testCase)
            origHtml = testCase.FixtureHtml;
            devTools = UIHTMLDevTools(testCase.Component);
            testCase.DevTools = devTools;

            % Initially enabled/injected
            tempFile = string(testCase.Component.HTMLSource);
            testCase.verifyNotEqual(tempFile, string(origHtml));
            testCase.verifyTrue(isfile(tempFile));

            % Set Enabled to same value
            devTools.Enabled = true;

            % Disable
            devTools.Enabled = false;
            testCase.verifyEqual(string(testCase.Component.HTMLSource), string(origHtml));
            testCase.verifyFalse(isfile(tempFile));

            % Re-enable
            devTools.Enabled = true;
            newTempFile = string(testCase.Component.HTMLSource);
            testCase.verifyNotEqual(newTempFile, string(origHtml));
            testCase.verifyTrue(isfile(newTempFile));
        end % function testEnabledToggle

        function testCleanup(testCase)
            devTools = UIHTMLDevTools(testCase.Component);
            testCase.DevTools = devTools;

            tempFile = string(testCase.Component.HTMLSource);
            targetDir = fileparts(testCase.FixtureHtml);
            pErudaDest = fullfile(targetDir, "eruda.js");

            % Perform cleanup by deleting the object
            delete(devTools);

            % Temp file and copied eruda.js are both deleted on destruction
            testCase.verifyFalse(isfile(tempFile));
            testCase.verifyFalse(isfile(pErudaDest));

            % Original HTMLSource is restored on destruction
            testCase.verifyEqual(string(testCase.Component.HTMLSource), testCase.FixtureHtml);
        end % function testCleanup

        function testNoBodyTag(testCase)
            tempDir = tempname;
            mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            noBodyHtml = fullfile(tempDir, "test_no_body.html");
            writelines("<html><p>No body</p></html>", noBodyHtml);
            testCase.Component.HTMLSource = noBodyHtml;

            devTools = UIHTMLDevTools(testCase.Component);
            testCase.addTeardown(@() delete(devTools));

            tempFile = string(testCase.Component.HTMLSource);
            content = fileread(tempFile);
            testCase.verifySubstring(content, "eruda.init()");
            testCase.verifyTrue(endsWith(strtrim(content), "</script>"));
        end % function testNoBodyTag

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
            
            devTools = UIHTMLDevTools(mockComp);
            testCase.addTeardown(@() delete(devTools));
            
            testCase.verifyTrue(isfile("eruda.js"));
            testCase.verifySubstring(string(mockComp.HTMLSource), "_devtools_");
        end % function testEmptyTargetDir

        function testCleanupWarnings(testCase)
            if isunix
                tempDir = tempname;
                mkdir(tempDir);
                testCase.addTeardown(@() rmdir(tempDir, 's'));
                htmlFile = fullfile(tempDir, "test.html");
                writelines("<html><body></body></html>", htmlFile);
                
                mockComp = MockComponent();
                mockComp.HTMLSource = htmlFile;
                devTools = UIHTMLDevTools(mockComp);
                
                % Make the temp file and eruda.js read-only
                tempFile = string(mockComp.HTMLSource);
                pErudaDest = fullfile(tempDir, "eruda.js");
                
                fileattrib(tempFile, '-w');
                testCase.addTeardown(@() fileattrib(tempFile, '+w'));
                fileattrib(pErudaDest, '-w');
                testCase.addTeardown(@() fileattrib(pErudaDest, '+w'));
                
                testCase.verifyWarning(@() delete(devTools), "uihtmlDevTools:FailedCleanup");
            end
        end % function testCleanupWarnings

        function testDeleteWithMissingFiles(testCase)
            devTools = UIHTMLDevTools(testCase.Component);
            
            % Delete files manually before object delete
            tempFile = string(testCase.Component.HTMLSource);
            delete(tempFile);
            
            targetDir = fileparts(testCase.FixtureHtml);
            pErudaDest = fullfile(targetDir, "eruda.js");
            if isfile(pErudaDest)
                delete(pErudaDest);
            end
            
            % Should not error/warning if they don't exist
            delete(devTools);
        end % function testDeleteWithMissingFiles

        function testDeleteInvalidComponent(testCase)
            devTools = UIHTMLDevTools(testCase.Component);
            testCase.DevTools = devTools;
            delete(testCase.Figure); % Deletes component too
            delete(devTools); % Should not error in removeEruda
            testCase.DevTools = [];
        end % function testDeleteInvalidComponent

        function testOriginalSourceDeleted(testCase)
            tempDir = tempname;
            mkdir(tempDir);
            testCase.addTeardown(@() rmdir(tempDir, 's'));
            htmlFile = fullfile(tempDir, "temp.html");
            writelines("<html><body></body></html>", htmlFile);
            
            mockComp = MockComponent();
            mockComp.HTMLSource = htmlFile;
            devTools = UIHTMLDevTools(mockComp);
            
            % Delete original source before devTools is deleted
            delete(htmlFile);
            
            % removeEruda should handle this gracefully
            delete(devTools);
            testCase.verifyEqual(string(mockComp.HTMLSource), string(htmlFile));
        end % function testOriginalSourceDeleted

        function testTempWriteFailure(testCase)
            if isunix
                tempDir = tempname;
                mkdir(tempDir);
                testCase.addTeardown(@() rmdir(tempDir, 's'));
                htmlFile = fullfile(tempDir, "test.html");
                writelines("<html><body></body></html>", htmlFile);
                
                % Make dir read-only
                fileattrib(tempDir, '-w');
                testCase.addTeardown(@() fileattrib(tempDir, '+w'));
                
                mockComp = MockComponent();
                mockComp.HTMLSource = htmlFile;
                testCase.verifyError(@() UIHTMLDevTools(mockComp), ...
                    "uihtmlDevTools:TempWriteFailure");
            end
        end % function testTempWriteFailure

        function testErudaCopyFailure(testCase)
            if isunix
                tempDir = tempname;
                mkdir(tempDir);
                testCase.addTeardown(@() rmdir(tempDir, 's'));
                htmlFile = fullfile(tempDir, "test.html");
                writelines("<html><body></body></html>", htmlFile);
                
                % Pre-create eruda.js and make it read-only or make dir read-only
                % Actually copyfile might fail if dest is read-only.
                pErudaDest = fullfile(tempDir, "eruda.js");
                writelines("locked", pErudaDest);
                fileattrib(pErudaDest, '-w');
                testCase.addTeardown(@() fileattrib(pErudaDest, '+w'));
                
                mockComp = MockComponent();
                mockComp.HTMLSource = htmlFile;
                testCase.verifyError(@() UIHTMLDevTools(mockComp), ...
                    "uihtmlDevTools:ErudaCopyFailure");
            end
        end % function testErudaCopyFailure

        function testUrlSourceMock(testCase)
            mockComp = MockComponent();
            mockComp.HTMLSource = "http://example.com";
            testCase.verifyError(@() UIHTMLDevTools(mockComp), ...
                "uihtmlDevTools:UrlHTMLSource");
        end % function testUrlSourceMock

        function testInvalidFileSourceMock(testCase)
            mockComp = MockComponent();
            mockComp.HTMLSource = "non_existent_file.html";
            testCase.verifyError(@() UIHTMLDevTools(mockComp), ...
                "uihtmlDevTools:InvalidHTMLSource");
        end % function testInvalidFileSourceMock
    end % methods (Test)
end % classdef tUIHTMLDevTools

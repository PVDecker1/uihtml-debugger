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
            testDir = fileparts(mfilename("fullpath"));
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
                "MATLAB:validation:UnableToConvert");
        end % function testConstructorInvalidComponent

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
    end % methods (Test)
end % classdef tUIHTMLDevTools